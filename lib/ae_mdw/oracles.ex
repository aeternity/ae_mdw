defmodule AeMdw.Oracles do
  @moduledoc """
  Context module for dealing with Oracles.
  """

  require AeMdw.Db.Model

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Oracle.t()
  @type oracle :: term()
  @type pagination :: Collection.direction_limit()
  @type opts() :: Util.opts()
  @type query_id() :: binary()

  @typep state() :: State.t()
  @typep range :: {:gen, Range.t()} | nil
  @typep query() :: %{binary() => binary()}
  @typep pubkey() :: Db.pubkey()

  @table_active AeMdw.Db.Model.ActiveOracle
  @table_active_expiration Model.ActiveOracleExpiration
  @table_inactive AeMdw.Db.Model.InactiveOracle
  @table_inactive_expiration Model.InactiveOracleExpiration

  @pagination_params ~w(limit cursor rev direction scope expand tx_hash)
  @states ~w(active inactive)

  @spec fetch_oracles(state(), pagination(), range(), query(), cursor() | nil, opts()) ::
          {:ok, cursor() | nil, [oracle()], cursor() | nil} | {:error, Error.t()}
  def fetch_oracles(state, pagination, range, query, cursor, opts) do
    cursor = deserialize_cursor(cursor)
    scope = deserialize_scope(range)

    try do
      {prev_cursor, expiration_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_streamer(state, scope, cursor)
        |> Collection.paginate(pagination)

      oracles = render_list(state, expiration_keys, opts)

      {:ok, serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
    rescue
      e in ErrInput -> {:error, e}
    end
  end

  defp convert_param({"state", state}) when state in @states, do: {:state, state}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)

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

  @spec fetch_active_oracles(state(), pagination(), cursor() | nil, opts()) ::
          {cursor() | nil, [oracle()], cursor() | nil}
  def fetch_active_oracles(state, pagination, cursor, opts) do
    cursor = deserialize_cursor(cursor)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(
        &Collection.stream(state, @table_active_expiration, &1, nil, cursor),
        pagination
      )

    oracles = render_list(state, exp_keys, true, opts)

    {serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch_inactive_oracles(state(), pagination(), cursor() | nil, opts()) ::
          {cursor() | nil, [oracle()], cursor() | nil}
  def fetch_inactive_oracles(state, pagination, cursor, opts) do
    cursor = deserialize_cursor(cursor)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(
        &Collection.stream(state, @table_inactive_expiration, &1, nil, cursor),
        pagination
      )

    oracles = render_list(state, exp_keys, false, opts)

    {serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch(state(), pubkey(), opts()) :: {:ok, oracle()} | {:error, Error.t()}
  def fetch(state, oracle_pk, opts) do
    last_gen = DBUtil.last_gen(state)

    case Oracle.locate(state, oracle_pk) do
      {m_oracle, source} ->
        {:ok, render(state, m_oracle, last_gen, source == Model.ActiveOracle, opts)}

      nil ->
        {:error,
         ErrInput.NotFound.exception(value: :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk))}
    end
  end

  defp render_list(state, oracles_exp_source_keys, opts) do
    last_gen = DBUtil.last_gen(state)

    Enum.map(oracles_exp_source_keys, fn {{_exp, oracle_pk}, source} ->
      is_active? = source == @table_active_expiration

      oracle =
        State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), oracle_pk)

      render(state, oracle, last_gen, is_active?, opts)
    end)
  end

  defp render_list(state, oracles_exp_keys, is_active?, opts) do
    last_gen = DBUtil.last_gen(state)

    oracles_exp_keys
    |> Enum.map(fn {_exp, oracle_pk} ->
      State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), oracle_pk)
    end)
    |> Enum.map(&render(state, &1, last_gen, is_active?, opts))
  end

  defp render(
         state,
         Model.oracle(
           index: pk,
           expire: expire_height,
           register: {{register_height, _mbi}, register_txi} = register_bi_txi,
           extends: extends,
           previous: _previous
         ),
         last_gen,
         is_active?,
         opts
       ) do
    kbi = min(expire_height - 1, last_gen)

    block_hash = Blocks.block_hash(state, kbi)
    oracle_tree = AeMdw.Db.Oracle.oracle_tree!(block_hash)
    oracle_rec = :aeo_state_tree.get_oracle(pk, oracle_tree)
    query_format = :aeo_oracles.query_format(oracle_rec)
    response_format = :aeo_oracles.response_format(oracle_rec)
    query_fee = :aeo_oracles.query_fee(oracle_rec)

    %{
      oracle: :aeser_api_encoder.encode(:oracle_pubkey, pk),
      active: is_active?,
      active_from: register_height,
      expire_height: expire_height,
      register: expand_txi(state, register_bi_txi, opts),
      register_tx_hash: :aeser_api_encoder.encode(:tx_hash, Txs.txi_to_hash(state, register_txi)),
      extends: Enum.map(extends, &expand_txi(state, &1, opts)),
      query_fee: query_fee,
      format: %{
        query: query_format,
        response: response_format
      }
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{{exp_height, oracle_pk}, _tab}, is_reversed?}),
    do: serialize_cursor({{exp_height, oracle_pk}, is_reversed?})

  defp serialize_cursor({{exp_height, oracle_pk}, is_reversed?}),
    do: {"#{exp_height}-#{:aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)}", is_reversed?}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    with [_match0, exp_height, encoded_pk] <- Regex.run(~r/(\d+)-(ok_\w+)/, cursor_bin),
         {:ok, pk} <- :aeser_api_encoder.safe_decode(:oracle_pubkey, encoded_pk) do
      {String.to_integer(exp_height), pk}
    else
      _nil_or_error -> nil
    end
  end

  defp expand_txi(state, bi_txi, opts) do
    txi = Format.bi_txi_txi(bi_txi)

    cond do
      Keyword.get(opts, :expand?, false) ->
        Txs.fetch!(state, txi)

      Keyword.get(opts, :tx_hash?, false) ->
        :aeser_api_encoder.encode(:tx_hash, Txs.txi_to_hash(state, txi))

      true ->
        txi
    end
  end

  defp deserialize_scope(nil), do: nil

  defp deserialize_scope({:gen, first_gen..last_gen}),
    do: {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
end
