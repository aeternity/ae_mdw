defmodule AeMdw.Oracles do
  @moduledoc """
  Context module for dealing with Oracles.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Oracle.t()
  @type oracle :: term()
  @type oracle_query() :: map()
  @type oracle_response() :: map()
  @type pagination :: Collection.direction_limit()
  @type opts() :: Util.opts()
  @type query_id() :: binary()

  @typep state() :: State.t()
  @typep range :: {:gen, Range.t()} | nil
  @typep query() :: %{binary() => binary()}
  @typep pubkey() :: Db.pubkey()
  @typep extends() :: %{
           height: Blocks.height(),
           block_hash: Blocks.block_hash(),
           source_tx_hash: Txs.tx_hash(),
           source_tx_type: Node.tx_type(),
           tx: map()
         }
  @typep paginated_extends() :: {cursor() | nil, [extends()], cursor() | nil}

  @table_active AeMdw.Db.Model.ActiveOracle
  @table_active_expiration Model.ActiveOracleExpiration
  @table_inactive AeMdw.Db.Model.InactiveOracle
  @table_inactive_expiration Model.InactiveOracleExpiration
  @table_query Model.OracleQuery

  @states ~w(active inactive)

  @spec fetch_oracles(state(), pagination(), range(), query(), cursor() | nil, opts()) ::
          {:ok, {cursor() | nil, [oracle()], cursor() | nil}} | {:error, Error.t()}
  def fetch_oracles(state, pagination, range, query, cursor, opts) do
    cursor = deserialize_cursor(cursor)
    scope = deserialize_scope(range)
    last_gen_time = DbUtil.last_gen_and_time(state)

    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      paginated_oracles =
        filters
        |> build_streamer(state, scope, cursor)
        |> Collection.paginate(
          pagination,
          &render(state, &1, last_gen_time, opts),
          &serialize_cursor/1
        )

      {:ok, paginated_oracles}
    end
  end

  @spec fetch_oracle_queries(state(), pubkey(), pagination(), range(), cursor() | nil) ::
          {:ok, {cursor() | nil, [oracle_query()], cursor() | nil}} | {:error, Error.t()}
  def fetch_oracle_queries(state, oracle_id, pagination, nil, cursor) do
    with {:ok, oracle_pk} <- Validate.id(oracle_id, [:oracle_pubkey]),
         {:ok, cursor} <- deserialize_queries_cursor(cursor, oracle_pk) do
      key_boundary = {{oracle_pk, Util.min_bin()}, {oracle_pk, Util.max_256bit_bin()}}

      paginated_queries =
        fn direction ->
          Collection.stream(state, @table_query, direction, key_boundary, cursor)
        end
        |> Collection.paginate(
          pagination,
          &render_query(state, &1, true),
          &serialize_queries_cursor/1
        )

      {:ok, paginated_queries}
    end
  end

  def fetch_oracle_queries(_state, _oracle_id, _pagination, _range, _cursor),
    do: {:error, ErrInput.Query.exception(value: "cannot filter by range on this endpoint")}

  @spec fetch_oracle_responses(state(), pubkey(), pagination(), range(), cursor() | nil) ::
          {:ok, {cursor() | nil, [oracle_response()], cursor() | nil}} | {:error, Error.t()}
  def fetch_oracle_responses(state, oracle_id, pagination, range, cursor) do
    with {:ok, oracle_pk} <- Validate.id(oracle_id, [:oracle_pubkey]),
         {:ok, cursor} <- deserialize_responses_cursor(cursor, oracle_pk) do
      key_boundary =
        case range do
          nil ->
            {
              {oracle_pk, "reward_oracle", {Util.min_int(), -1}, -1},
              {oracle_pk, "reward_oracle", {Util.max_int(), -1}, -1}
            }

          first_gen..last_gen ->
            {
              {oracle_pk, "reward_oracle", {first_gen, Util.min_int()}, -1},
              {oracle_pk, "reward_oracle", {last_gen, Util.max_int()}, -1}
            }
        end

      paginated_responses =
        fn direction ->
          state
          |> Collection.stream(Model.TargetKindIntTransferTx, direction, key_boundary, cursor)
          |> Stream.map(fn {^oracle_pk, "reward_oracle", {height, txi_idx}, ref_txi_idx} ->
            {height, txi_idx, ref_txi_idx}
          end)
        end
        |> Collection.paginate(
          pagination,
          &render_response(state, &1, true),
          &serialize_responses_cursor/1
        )

      {:ok, paginated_responses}
    end
  end

  defp deserialize_queries_cursor(nil, _oracle_pk), do: {:ok, nil}

  defp deserialize_queries_cursor(query_id, oracle_pk) do
    case Enc.safe_decode(:oracle_query_id, query_id) do
      {:ok, query_id} -> {:ok, {oracle_pk, query_id}}
      {:error, _reason} -> {:error, ErrInput.Cursor.exception(value: query_id)}
    end
  end

  defp serialize_queries_cursor({_oracle_pk, query_id}),
    do: Enc.encode(:oracle_query_id, query_id)

  defp deserialize_responses_cursor(nil, _oracle_pk), do: {:ok, nil}

  defp deserialize_responses_cursor(cursor_bin, oracle_pk) do
    case Regex.run(~r/\A(\d+)-(\d+)-(\d+)-(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [height_bin, txi_bin, idx_bin, ref_txi_bin, ref_idx_bin] ->
        height = String.to_integer(height_bin)
        txi = String.to_integer(txi_bin)
        idx = String.to_integer(idx_bin) - 1
        ref_txi = String.to_integer(ref_txi_bin)
        ref_idx = String.to_integer(ref_idx_bin) - 1

        {:ok, {oracle_pk, "reward_oracle", {height, {txi, idx}}, {ref_txi, ref_idx}}}

      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp serialize_responses_cursor({height, {txi, idx}, {ref_txi, ref_idx}}),
    do: "#{height}-#{txi}-#{idx + 1}-#{ref_txi}-#{ref_idx + 1}"

  defp render_query(state, {oracle_pk, query_id}, include_response?) do
    Model.oracle_query(txi_idx: {txi, _idx} = txi_idx, response_txi_idx: response_txi_idx) =
      State.fetch!(state, Model.OracleQuery, {oracle_pk, query_id})

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    {query_tx, :oracle_query_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    block_time = Db.get_block_time(block_hash)

    query =
      %{
        height: height,
        block_hash: Enc.encode(:micro_block_hash, block_hash),
        block_time: block_time,
        source_tx_hash: Enc.encode(:tx_hash, tx_hash),
        source_tx_type: Node.tx_name(tx_type),
        query_id: Enc.encode(:oracle_query_id, query_id)
      }
      |> Map.merge(:aeo_query_tx.for_client(query_tx))
      |> update_in(["query"], &Base.encode64/1)

    if include_response? do
      Map.put(
        query,
        :response,
        response_txi_idx && render_response(state, response_txi_idx, false)
      )
    else
      query
    end
  end

  defp render_response(state, {_height, txi_idx, _ref_txi_idx}, include_query?),
    do: render_response(state, txi_idx, include_query?)

  defp render_response(state, {txi, _idx} = txi_idx, include_query?) do
    {response_tx, :oracle_response_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    query_id = :aeo_response_tx.query_id(response_tx)
    oracle_pk = :aeo_response_tx.oracle_pubkey(response_tx)
    block_time = Db.get_block_time(block_hash)

    response =
      %{
        height: height,
        block_hash: Enc.encode(:micro_block_hash, block_hash),
        block_time: block_time,
        source_tx_hash: Enc.encode(:tx_hash, tx_hash),
        source_tx_type: Node.tx_name(tx_type),
        query_id: Enc.encode(:oracle_query_id, query_id)
      }
      |> Map.merge(:aeo_response_tx.for_client(response_tx))
      |> update_in(["response"], &Base.encode64/1)

    if include_query? do
      Map.put(response, :query, render_query(state, {oracle_pk, query_id}, false))
    else
      response
    end
  end

  defp convert_param({"state", state}) when state in @states, do: {:ok, {:state, state}}

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}

  defp build_streamer(%{state: "active"}, state, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_active_expiration, direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_active_expiration} end)
    end
  end

  defp build_streamer(%{state: "inactive"}, state, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_inactive_expiration, direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_inactive_expiration} end)
    end
  end

  defp build_streamer(%{}, state, scope, cursor) do
    fn direction ->
      active_stream =
        state
        |> Collection.stream(@table_active_expiration, direction, scope, cursor)
        |> Stream.map(fn key -> {key, @table_active_expiration} end)

      inactive_stream =
        state
        |> Collection.stream(@table_inactive_expiration, direction, scope, cursor)
        |> Stream.map(fn key -> {key, @table_inactive_expiration} end)

      case direction do
        :forward -> Stream.concat(inactive_stream, active_stream)
        :backward -> Stream.concat(active_stream, inactive_stream)
      end
    end
  end

  @spec fetch(state(), pubkey(), opts()) :: {:ok, oracle()} | {:error, Error.t()}
  def fetch(state, oracle_pk, opts) do
    last_gen_time = DbUtil.last_gen_and_time(state)

    case Oracle.locate(state, oracle_pk) do
      {m_oracle, source} ->
        {:ok, render(state, m_oracle, source == Model.ActiveOracle, last_gen_time, opts)}

      nil ->
        {:error, ErrInput.NotFound.exception(value: Enc.encode(:oracle_pubkey, oracle_pk))}
    end
  end

  @spec fetch_oracle_extends(state(), binary(), pagination(), cursor() | nil) ::
          {:ok, paginated_extends()} | {:error, Error.t()}
  def fetch_oracle_extends(state, oracle_id, pagination, cursor) do
    with {:ok, oracle_pk} <- Validate.id(oracle_id, [:oracle_pubkey]),
         {:ok, cursor} <- deserialize_nested_cursor(cursor),
         {Model.oracle(extends: extends), _source} <- Oracle.locate(state, oracle_pk) do
      extends
      |> build_oracle_extends_streamer(cursor)
      |> Collection.paginate(pagination, &render_extend(state, &1), &serialize_nested_cursor/1)
      |> then(&{:ok, &1})
    else
      nil -> {:error, ErrInput.NotFound.exception(value: oracle_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_oracle_extends_streamer(extends, cursor) do
    fn
      :forward when is_nil(cursor) ->
        Enum.reverse(extends)

      :backward when is_nil(cursor) ->
        extends

      :forward ->
        extends
        |> Enum.reverse()
        |> Enum.drop_while(&(&1 < cursor))

      :backward ->
        Enum.drop_while(extends, &(&1 > cursor))
    end
  end

  defp render(state, {{exp, oracle_pk}, source}, last_gen_time, opts) do
    is_active? = source == @table_active_expiration

    render(state, {exp, oracle_pk}, is_active?, last_gen_time, opts)
  end

  defp render(state, {_exp, oracle_pk}, is_active?, last_gen_time, opts) do
    oracle =
      State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), oracle_pk)

    render(state, oracle, is_active?, last_gen_time, opts)
  end

  defp render(
         state,
         Model.oracle(
           index: pk,
           expire: expire_height,
           register:
             {{register_height, _mbi} = register_bi, {register_txi, _register_idx}} =
               register_bi_txi_idx,
           extends: extends,
           previous: _previous
         ),
         is_active?,
         {last_gen, last_micro_time},
         opts
       ) do
    kbi = min(expire_height - 1, last_gen)

    oracle_tree =
      state
      |> Blocks.block_hash(kbi)
      |> AeMdw.Db.Oracle.oracle_tree!()

    oracle_rec = :aeo_state_tree.get_oracle(pk, oracle_tree)
    query_format = :aeo_oracles.query_format(oracle_rec)
    response_format = :aeo_oracles.response_format(oracle_rec)
    query_fee = :aeo_oracles.query_fee(oracle_rec)

    oracle = %{
      oracle: Enc.encode(:oracle_pubkey, pk),
      active: is_active?,
      active_from: register_height,
      register_time: DbUtil.block_index_to_time(state, register_bi),
      expire_height: expire_height,
      approximate_expire_time:
        DbUtil.height_to_time(state, expire_height, last_gen, last_micro_time),
      register: expand_bi_txi_idx(state, register_bi_txi_idx, opts),
      register_tx_hash: Enc.encode(:tx_hash, Txs.txi_to_hash(state, register_txi)),
      query_fee: query_fee,
      format: %{
        query: query_format,
        response: response_format
      }
    }

    if Keyword.get(opts, :v3?, false) do
      oracle
    else
      Map.put(oracle, :extends, Enum.map(extends, &expand_bi_txi_idx(state, &1, opts)))
    end
  end

  defp render_extend(state, {{height, _mbi}, txi_idx}) do
    {tx_rec, :oracle_extend_tx, tx_hash, chain_tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Node.tx_name(chain_tx_type),
      tx: :aeo_extend_tx.for_client(tx_rec)
    }
  end

  defp serialize_cursor({{exp_height, oracle_pk}, _tab}),
    do: serialize_cursor({exp_height, oracle_pk})

  defp serialize_cursor({exp_height, oracle_pk}),
    do: "#{exp_height}-#{Enc.encode(:oracle_pubkey, oracle_pk)}"

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    with [_match0, exp_height, encoded_pk] <- Regex.run(~r/(\d+)-(ok_\w+)/, cursor_bin),
         {:ok, pk} <- Enc.safe_decode(:oracle_pubkey, encoded_pk) do
      {String.to_integer(exp_height), pk}
    else
      _nil_or_error -> nil
    end
  end

  defp expand_bi_txi_idx(state, {_bi, {txi, _idx}}, opts) do
    cond do
      Keyword.get(opts, :v3?, false) ->
        state
        |> Txs.fetch!(txi)
        |> put_in(["tx", "tx_hash"], Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi)))
        |> Map.drop(["tx_index"])

      Keyword.get(opts, :expand?, false) ->
        Txs.fetch!(state, txi)

      Keyword.get(opts, :tx_hash?, false) ->
        Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi))

      true ->
        txi
    end
  end

  defp deserialize_scope(nil), do: nil

  defp deserialize_scope({:gen, first_gen..last_gen}),
    do: {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}

  defp serialize_nested_cursor({{height, mbi}, {txi, idx}}),
    do: "#{height}-#{mbi}-#{txi}-#{idx + 1}"

  defp deserialize_nested_cursor(nil), do: {:ok, nil}

  defp deserialize_nested_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)-(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      nil ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin)}

      values ->
        [height, mbi, txi, idx] = Enum.map(values, &String.to_integer/1)

        {:ok, {{height, mbi}, {txi, idx - 1}}}
    end
  end
end
