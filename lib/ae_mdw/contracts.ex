defmodule AeMdw.Contracts do
  @moduledoc """
  Context module for dealing with Contracts.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model
  require Contract

  @type log() :: Model.contract_log_index()
  @type contract() :: map()
  @type call() :: map()
  @type cursor() :: binary() | nil
  @type query() :: %{binary() => binary()}
  @type local_idx() :: non_neg_integer()
  @type event_hash() :: <<_::256>>
  @type log_idx() :: non_neg_integer()

  @typep state() :: State.t()
  @typep reason() :: binary()
  @typep pagination() :: Collection.direction_limit()
  @typep range() :: {:gen, Range.t()} | {:txi, Range.t()} | nil
  @typep logs_opt() :: {:v3?, boolean()}

  @contract_log_table Model.ContractLog
  @idx_contract_log_table Model.IdxContractLog
  @ctevt_contract_log_table Model.CtEvtContractLog
  @evt_contract_log_table Model.EvtContractLog
  @data_contract_log_table Model.DataContractLog
  @int_contract_call_table Model.IntContractCall
  @grp_int_contract_call_table Model.GrpIntContractCall
  @fname_int_contract_call_table Model.FnameIntContractCall
  @fname_grp_contract_call_table Model.FnameGrpIntContractCall
  @id_int_contract_call_table Model.IdIntContractCall
  @grp_id_int_contract_call_table Model.GrpIdIntContractCall

  @min_fname Util.min_bin()
  @max_256bit_bin Util.max_256bit_bin()
  @min_idx Util.min_int()
  @max_idx Util.max_int()
  @min_pubkey Util.min_bin()
  @min_id_pos 0
  @min_txi Util.min_int()
  @max_txi Util.max_int()
  @max_blob :binary.list_to_bin(:lists.duplicate(1024, Util.max_256bit_bin()))

  @spec fetch_contracts(state(), pagination(), range(), cursor()) ::
          {:ok, {cursor(), [contract()], cursor()}} | {:error, reason()}
  def fetch_contracts(state, pagination, range, cursor) do
    with {:ok, cursor} <- deserialize_contracts_cursor(cursor) do
      scope = deserialize_scope(state, range)

      paginated_contracts =
        fn direction ->
          ~w(contract_create_tx ga_attach_tx)a
          |> Enum.map(fn tx_type ->
            DBUtil.transactions_of_type(state, tx_type, direction, scope, cursor)
          end)
          |> Collection.merge(direction)
        end
        |> Collection.paginate(
          pagination,
          &render_contract(state, &1),
          &serialize_contracts_cursor/1
        )

      {:ok, paginated_contracts}
    end
  end

  @spec fetch_logs(State.t(), pagination(), range(), query(), cursor(), [logs_opt()]) ::
          {:ok, {cursor(), [log()], cursor()}} | {:error, Error.t()}
  def fetch_logs(state, pagination, range, query, cursor, opts) do
    cursor = deserialize_logs_cursor(cursor)
    scope = deserialize_scope(state, range)

    with {:ok, filters} <- Util.convert_params(query, &convert_logs_param(state, &1)) do
      encode_args = %{
        aexn_args?: Map.get(filters, :aexn_args, false),
        custom_args?: Map.get(filters, :custom_args, false)
      }

      paginated_logs =
        filters
        |> build_logs_pagination(state, scope, cursor)
        |> Collection.paginate(
          pagination,
          &render_log(state, &1, encode_args, opts),
          &serialize_logs_cursor/1
        )

      {:ok, paginated_logs}
    end
  end

  @spec fetch_contract_logs(State.t(), binary(), pagination(), range(), query(), cursor()) ::
          {:ok, {cursor(), [log()], cursor()}} | {:error, Error.t()}
  def fetch_contract_logs(state, contract_id, pagination, range, query, cursor) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, filters} <- Util.convert_params(query, &convert_logs_param(state, &1)),
         {:ok, create_txi} <- create_txi(state, contract_pk) do
      cursor = deserialize_logs_cursor(cursor)
      scope = deserialize_scope(state, range)

      encode_args = %{
        aexn_args?: Map.get(filters, :aexn_args, false),
        custom_args?: Map.get(filters, :custom_args, false)
      }

      filters
      |> Map.put(:create_txi, create_txi)
      |> build_logs_pagination(state, scope, cursor)
      |> Collection.paginate(
        pagination,
        &render_log(state, &1, encode_args, v3?: true),
        &serialize_logs_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_contract_calls(State.t(), binary(), pagination(), range(), query(), cursor()) ::
          {:ok, {cursor(), [call()], cursor()}} | {:error, Error.t()}
  def fetch_contract_calls(state, contract_id, pagination, range, query, cursor) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, filters} <- Util.convert_params(query, &convert_param(state, &1)),
         {:ok, create_txi} <- create_txi(state, contract_pk) do
      cursor = deserialize_calls_cursor(cursor)
      scope = deserialize_scope(state, range)

      filters
      |> Map.put(:create_txi, create_txi)
      |> build_calls_pagination(state, scope, cursor)
      |> Collection.paginate(
        pagination,
        &render_call(state, &1, v3?: true),
        &serialize_calls_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_calls(State.t(), pagination(), range(), query(), cursor(), Keyword.t()) ::
          {:ok, {cursor(), [call()], cursor()}} | {:error, Error.t()}
  def fetch_calls(state, pagination, range, query, cursor, opts) do
    cursor = deserialize_calls_cursor(cursor)
    scope = deserialize_scope(state, range)

    with {:ok, filters} <- Util.convert_params(query, &convert_param(state, &1)) do
      paginated_calls =
        filters
        |> build_calls_pagination(state, scope, cursor)
        |> Collection.paginate(
          pagination,
          &render_call(state, &1, opts),
          &serialize_calls_cursor/1
        )

      {:ok, paginated_calls}
    end
  end

  @spec fetch_int_contract_calls(State.t(), Txs.txi(), Contract.fname()) :: Enumerable.t()
  def fetch_int_contract_calls(state, txi, fname) do
    state
    |> Collection.stream(@int_contract_call_table, {txi, @min_idx})
    |> Stream.take_while(fn {call_txi, _local_txi} -> call_txi == txi end)
    |> Stream.map(&State.fetch!(state, @int_contract_call_table, &1))
    |> Stream.filter(&match?(Model.int_contract_call(fname: ^fname), &1))
  end

  @spec fetch_contract(State.t(), binary()) :: {:ok, contract()} | {:error, reason()}
  def fetch_contract(state, contract_id) do
    with {:ok, pubkey} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, txi_idx} <- get_contract_txi_idx(state, pubkey) do
      {:ok, render_contract(state, txi_idx)}
    else
      {:error, reason} -> {:error, reason}
      _preset_or_not_found -> {:error, ErrInput.NotFound.exception(value: contract_id)}
    end
  end

  #
  # Private functions
  #
  def get_contract_txi_idx(state, pubkey) do
    with {:ok, txi} when txi >= 0 <- Origin.tx_index(state, {:contract, pubkey}),
         Model.tx(id: tx_hash) <- State.fetch!(state, Model.Tx, txi),
         {outer_tx_type, _tx} <- Db.get_tx(tx_hash) do
      if outer_tx_type == :contract_call_tx do
        local_idx =
          Contract.contract_create_fnames()
          |> Enum.map(&fetch_int_contract_calls(state, txi, &1))
          |> Stream.concat()
          |> Enum.find_value(fn Model.int_contract_call(index: {^txi, local_idx}) ->
            create_tx = DBUtil.read_node_tx(state, {txi, local_idx})

            :aect_create_tx.contract_pubkey(create_tx) == pubkey && local_idx
          end)

        {:ok, {txi, local_idx}}
      else
        {:ok, {txi, -1}}
      end
    end
  end

  defp build_logs_pagination(
         %{data_prefix: data_prefix},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    key_boundary = {
      {data_prefix, first_call_txi, @min_txi, @min_idx},
      {data_prefix <> @max_blob, last_call_txi, @max_txi, @max_idx}
    }

    cursor =
      with {create_txi, call_txi, log_idx} <- cursor do
        key = {create_txi, call_txi, log_idx}
        Model.contract_log(data: data) = State.fetch!(state, @contract_log_table, key)
        {data, call_txi, create_txi, log_idx}
      end

    fn direction ->
      state
      |> Collection.stream(@data_contract_log_table, direction, key_boundary, cursor)
      |> Stream.map(fn {_data, call_txi, create_txi, log_idx} ->
        {create_txi, call_txi, log_idx}
      end)
    end
  end

  defp build_logs_pagination(
         %{event_hash: event_hash, create_txi: create_txi},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    key_boundary = {
      {event_hash, create_txi, first_call_txi, @min_idx},
      {event_hash, create_txi, last_call_txi, @max_idx}
    }

    cursor =
      with {create_txi, call_txi, log_idx} <- cursor do
        {event_hash, create_txi, call_txi, log_idx}
      end

    fn direction ->
      state
      |> Collection.stream(@ctevt_contract_log_table, direction, key_boundary, cursor)
      |> Stream.map(fn {_hash, create_txi, call_txi, log_idx} ->
        {create_txi, call_txi, log_idx}
      end)
    end
  end

  defp build_logs_pagination(
         %{event_hash: event_hash},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    key_boundary = {
      {event_hash, first_call_txi, @min_txi, @min_idx},
      {event_hash, last_call_txi, @max_txi, @max_idx}
    }

    cursor =
      with {create_txi, call_txi, log_idx} <- cursor do
        {event_hash, call_txi, create_txi, log_idx}
      end

    fn direction ->
      state
      |> Collection.stream(@evt_contract_log_table, direction, key_boundary, cursor)
      |> Stream.map(fn {_hash, call_txi, create_txi, log_idx} ->
        {create_txi, call_txi, log_idx}
      end)
    end
  end

  defp build_logs_pagination(
         %{create_txi: create_txi},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    key_boundary = {
      {create_txi, first_call_txi, @min_idx},
      {create_txi, last_call_txi, @max_idx}
    }

    fn direction ->
      Collection.stream(state, @contract_log_table, direction, key_boundary, cursor)
    end
  end

  defp build_logs_pagination(_query, state, {first_call_txi, last_call_txi}, cursor) do
    key_boundary = {
      {first_call_txi, @min_txi, @min_idx},
      {last_call_txi, @max_txi, @max_idx}
    }

    cursor =
      with {create_txi, call_txi, log_idx} <- cursor do
        {call_txi, log_idx, create_txi}
      end

    fn direction ->
      state
      |> Collection.stream(@idx_contract_log_table, direction, key_boundary, cursor)
      |> Stream.map(fn {call_txi, log_idx, create_txi} ->
        {create_txi, call_txi, log_idx}
      end)
    end
  end

  defp build_calls_pagination(
         %{create_txi: create_txi, fname: fname_prefix},
         state,
         scope,
         cursor
       ) do
    cursor =
      with {call_txi, local_idx, _create_txi, _pk, fname, _pos} <- cursor do
        {fname, create_txi, call_txi, local_idx}
      end

    fnames =
      fname_prefix
      |> Stream.unfold(fn prefix ->
        case State.next(state, @fname_int_contract_call_table, {prefix, @min_txi, @min_idx}) do
          {:ok, {next_fname, _txi, _idx}} -> {next_fname, next_fname <> @max_256bit_bin}
          :none -> nil
        end
      end)
      |> Enum.take_while(&String.starts_with?(&1, fname_prefix))

    fn direction ->
      fnames
      |> Enum.map(&build_calls_grp_fname_stream(state, &1, direction, scope, cursor, create_txi))
      |> Collection.merge(direction)
    end
  end

  defp build_calls_pagination(%{fname: fname_prefix}, state, scope, cursor) do
    cursor =
      with {call_txi, local_idx, _create_txi, _pk, fname, _pos} <- cursor do
        {fname, call_txi, local_idx}
      end

    fnames =
      fname_prefix
      |> Stream.unfold(fn prefix ->
        case State.next(state, @fname_int_contract_call_table, {prefix, @min_txi, @min_idx}) do
          {:ok, {next_fname, _txi, _idx}} -> {next_fname, next_fname <> @max_256bit_bin}
          :none -> nil
        end
      end)
      |> Enum.take_while(&String.starts_with?(&1, fname_prefix))

    fn direction ->
      fnames
      |> Enum.map(&build_calls_fname_stream(state, &1, direction, scope, cursor))
      |> Collection.merge(direction)
    end
  end

  defp build_calls_pagination(
         %{create_txi: create_txi, type_pos: {pos_types, pk}},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    collections =
      Enum.map(pos_types, fn {tx_pos, tx_types} ->
        cursor =
          with {call_txi, local_idx, _create_txi, _pk, _fname, _pos} <- cursor do
            {create_txi, pk, tx_pos, call_txi, local_idx}
          end

        key_boundary = {
          {create_txi, pk, tx_pos, first_call_txi, @min_idx},
          {create_txi, pk, tx_pos, last_call_txi, @max_idx}
        }

        {key_boundary, cursor, tx_types}
      end)

    fn direction ->
      collections
      |> Enum.map(fn {scope, cursor, tx_types} ->
        build_grp_id_calls_stream(state, direction, scope, cursor, tx_types)
      end)
      |> Collection.merge(direction)
      |> Stream.map(fn {create_txi, pk, call_txi, local_idx, pos} ->
        {call_txi, local_idx, create_txi, pk, @min_fname, pos}
      end)
    end
  end

  defp build_calls_pagination(
         %{create_txi: create_txi},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    key_boundary = {{create_txi, first_call_txi, @min_idx}, {create_txi, last_call_txi, @max_idx}}

    cursor =
      with {call_txi, local_idx, _create_txi, _pk, _fname, _pos} <- cursor do
        {create_txi, call_txi, local_idx}
      end

    fn direction ->
      state
      |> Collection.stream(@grp_int_contract_call_table, direction, key_boundary, cursor)
      |> Stream.map(fn {create_txi, call_txi, local_idx} ->
        {call_txi, local_idx, create_txi, @min_pubkey, @min_fname, @min_id_pos}
      end)
    end
  end

  defp build_calls_pagination(
         %{type_pos: {pos_types, pk}},
         state,
         {first_call_txi, last_call_txi},
         cursor
       ) do
    collections =
      Enum.map(pos_types, fn {tx_pos, tx_types} ->
        cursor =
          with {call_txi, local_idx, _create_txi, _pk, _fname, _pos} <- cursor do
            {pk, tx_pos, call_txi, local_idx}
          end

        key_boundary =
          {{pk, tx_pos, first_call_txi, @min_idx}, {pk, tx_pos, last_call_txi, @max_idx}}

        {key_boundary, cursor, tx_types}
      end)

    fn direction ->
      collections
      |> Enum.map(fn {key_boundary, cursor, tx_types} ->
        build_id_int_call_stream(state, direction, key_boundary, cursor, tx_types)
      end)
      |> Collection.merge(direction)
      |> Stream.map(fn {pk, call_txi, local_idx, pos} ->
        {call_txi, local_idx, @min_txi, pk, @min_fname, pos}
      end)
    end
  end

  defp build_calls_pagination(query, state, {first_call_txi, last_call_txi}, cursor)
       when map_size(query) == 0 do
    key_boundary = {{first_call_txi, @min_idx}, {last_call_txi, @max_idx}}

    cursor =
      with {call_txi, local_idx, _create_txi, _pk, _fname, _pos} <- cursor do
        {call_txi, local_idx}
      end

    fn direction ->
      state
      |> Collection.stream(@int_contract_call_table, direction, key_boundary, cursor)
      |> Stream.map(fn {call_txi, local_idx} ->
        {call_txi, local_idx, @min_txi, @min_pubkey, @min_fname, @min_id_pos}
      end)
    end
  end

  defp build_grp_id_calls_stream(state, direction, scope, cursor, tx_types) do
    state
    |> Collection.stream(@grp_id_int_contract_call_table, direction, scope, cursor)
    |> Stream.filter(fn {_create_txi, _pk, _pos, call_txi, local_idx} ->
      Enum.member?(tx_types, fetch_tx_type(state, call_txi, local_idx))
    end)
    |> Stream.map(fn {create_txi, pk, pos, call_txi, local_idx} ->
      {create_txi, pk, call_txi, local_idx, pos}
    end)
  end

  defp build_id_int_call_stream(state, direction, scope, cursor, tx_types) do
    state
    |> Collection.stream(@id_int_contract_call_table, direction, scope, cursor)
    |> Stream.filter(fn {_pk, _pos, call_txi, local_idx} ->
      {tx_type, _tx} =
        state
        |> State.fetch!(Model.IntContractCall, {call_txi, local_idx})
        |> Model.int_contract_call(:tx)
        |> :aetx.specialize_type()

      Enum.member?(tx_types, tx_type)
    end)
    |> Stream.map(fn {pk, pos, call_txi, local_idx} ->
      {pk, call_txi, local_idx, pos}
    end)
  end

  defp build_calls_grp_fname_stream(
         state,
         fname,
         direction,
         {first_txi, last_txi},
         cursor,
         create_txi
       ) do
    key_boundary = {
      {fname, create_txi, first_txi, @min_idx},
      {fname, create_txi, last_txi, @max_idx}
    }

    state
    |> Collection.stream(@fname_grp_contract_call_table, direction, key_boundary, cursor)
    |> Stream.map(fn {^fname, ^create_txi, call_txi, local_idx} ->
      {call_txi, local_idx, create_txi, @min_pubkey, fname, @min_id_pos}
    end)
  end

  defp build_calls_fname_stream(state, fname, direction, {first_txi, last_txi}, cursor) do
    key_boundary = {{fname, first_txi, @min_idx}, {fname, last_txi, @max_idx}}

    state
    |> Collection.stream(@fname_int_contract_call_table, direction, key_boundary, cursor)
    |> Stream.map(fn {^fname, call_txi, local_idx} ->
      {call_txi, local_idx, @min_txi, @min_pubkey, fname, @min_id_pos}
    end)
  end

  defp convert_logs_param(_state, {"aexn-args", value}) when value in ~w(true false),
    do: {:ok, {:aexn_args, value == "true"}}

  defp convert_logs_param(_state, {"aexn-args", _val}),
    do: {:error, ErrInput.Query.exception(value: "aexn-args should be either true or false")}

  defp convert_logs_param(_state, {"custom-args", value}) when value in ~w(true false),
    do: {:ok, {:custom_args, value == "true"}}

  defp convert_logs_param(_state, {"custom-args", _val}),
    do: {:error, ErrInput.Query.exception(value: "custom-args should be either true or false")}

  defp convert_logs_param(state, arg), do: convert_param(state, arg)

  defp convert_param(state, {"contract_id", contract_id}),
    do: convert_param(state, {"contract", contract_id})

  defp convert_param(state, {"contract", contract_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id),
         {:ok, create_txi} <- create_txi(state, contract_pk) do
      {:ok, {:create_txi, create_txi}}
    end
  end

  defp convert_param(_state, {"data", data}), do: {:ok, {:data_prefix, URI.decode(data)}}

  defp convert_param(_state, {"event", ctor_name}),
    do: {:ok, {:event_hash, :aec_hash.blake2b_256_hash(ctor_name)}}

  defp convert_param(_state, {"function", fname}) when byte_size(fname) > 0,
    do: {:ok, {:fname, fname}}

  defp convert_param(state, {"function_prefix", fname}),
    do: {:ok, convert_param(state, {"function", fname})}

  defp convert_param(_state, {"aexn-args", _}), do: {:ok, {:ignore, nil}}

  defp convert_param(_state, {id_key, id_val}) do
    with {:ok, pubkey} <- Validate.id(id_val),
         {:ok, tx_types_positions} <- Parser.parse_field(id_key) do
      pos_types =
        tx_types_positions
        |> Enum.flat_map(fn {tx_type, positions} -> Enum.map(positions, &{&1, tx_type}) end)
        |> Enum.group_by(fn {pos, _tx_type} -> pos end, fn {_pos, tx_type} -> tx_type end)

      {:ok, {:type_pos, {pos_types, pubkey}}}
    end
  end

  defp deserialize_scope(_state, nil), do: {@min_txi, @max_txi}

  defp deserialize_scope(state, {:gen, first_gen..last_gen}) do
    first = DBUtil.gen_to_txi(state, first_gen)
    last = DBUtil.gen_to_txi(state, last_gen + 1) - 1
    deserialize_scope(state, {:txi, first..last})
  end

  defp deserialize_scope(_state, {:txi, first_txi..last_txi}), do: {first_txi, last_txi}

  defp create_txi(state, contract_pk) do
    with :not_found <- Origin.tx_index(state, {:contract, contract_pk}) do
      {:error, ErrInput.Id.exception(value: Enc.encode(:contract_pubkey, contract_pk))}
    end
  end

  defp fetch_tx_type(state, call_txi, local_idx) do
    {tx_type, _tx} =
      state
      |> State.fetch!(Model.IntContractCall, {call_txi, local_idx})
      |> Model.int_contract_call(:tx)
      |> :aetx.specialize_type()

    tx_type
  end

  defp render_call(state, {call_txi, local_idx, _create_txi, _pk, _fname, _pos}, opts) do
    call_key = {call_txi, local_idx}

    call = Format.to_map(state, call_key, @int_contract_call_table)

    if Keyword.get(opts, :v3?, true) do
      Map.drop(call, ~w(call_txi contract_txi)a)
    else
      call
    end
  end

  defp render_contract(state, create_txi_idx) do
    {create_tx, inner_tx_type, tx_hash, source_tx_type, block_hash} =
      DBUtil.read_node_tx_details(state, create_txi_idx)

    {contract_pk, encoded_tx} =
      case inner_tx_type do
        :contract_create_tx ->
          {:aect_create_tx.contract_pubkey(create_tx), :aect_create_tx.for_client(create_tx)}

        :ga_attach_tx ->
          {:aega_attach_tx.contract_pubkey(create_tx), :aega_attach_tx.for_client(create_tx)}

        tx_type when tx_type in ~w(paying_for_tx ga_meta_tx)a ->
          {:contract_create_tx, create_tx} =
            tx_type
            |> InnerTx.signed_tx(create_tx)
            |> :aetx_sign.tx()
            |> :aetx.specialize_type()

          {:aect_create_tx.contract_pubkey(create_tx), :aect_create_tx.for_client(create_tx)}
      end

    %{
      aexn_type: DbContract.get_aexn_type(state, contract_pk),
      contract: Enc.encode(:contract_pubkey, contract_pk),
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Node.tx_name(source_tx_type),
      create_tx: encoded_tx
    }
  end

  defp render_log(state, {create_txi, call_txi, log_idx} = index, encode_args, opts) do
    {contract_tx_hash, ct_pk} =
      if create_txi == -1 do
        {nil, Origin.pubkey(state, {:contract_call, call_txi})}
      else
        tx_hash = Enc.encode(:tx_hash, Txs.txi_to_hash(state, create_txi))

        {tx_hash, Origin.pubkey(state, {:contract, create_txi})}
      end

    v3? = Keyword.get(opts, :v3?, true)

    Model.tx(id: call_tx_hash, block_index: {height, micro_index}) =
      State.fetch!(state, Model.Tx, call_txi)

    Model.block(hash: block_hash) = DBUtil.read_block!(state, {height, micro_index})

    Model.contract_log(args: args, data: data, ext_contract: ext_contract, hash: event_hash) =
      State.fetch!(state, Model.ContractLog, index)

    event_name = AexnContracts.event_name(event_hash) || get_custom_event_name(event_hash)

    state
    |> render_remote_log_fields(ext_contract)
    |> Map.merge(%{
      contract_txi: create_txi,
      contract_tx_hash: contract_tx_hash,
      contract_id: encode_contract(ct_pk),
      call_txi: call_txi,
      call_tx_hash: Enc.encode(:tx_hash, call_tx_hash),
      block_time: DBUtil.block_time(block_hash),
      args: format_args(event_name, args, encode_args),
      data: maybe_encode_base64(data),
      event_hash: Base.hex_encode32(event_hash),
      event_name: event_name,
      height: height,
      micro_index: micro_index,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      log_idx: log_idx
    })
    |> maybe_remove_logs_txis(v3?)
  end

  defp maybe_remove_logs_txis(log, true) do
    Map.drop(log, [:contract_txi, :call_txi, :ext_caller_contract_txi])
  end

  defp maybe_remove_logs_txis(log, false) do
    log
  end

  defp render_remote_log_fields(_state, nil) do
    %{
      ext_caller_contract_tx_hash: nil,
      ext_caller_contract_id: nil,
      parent_contract_id: nil
    }
  end

  defp render_remote_log_fields(_state, {:parent_contract_pk, parent_pk}) do
    %{
      ext_caller_contract_txi: -1,
      ext_caller_contract_tx_hash: nil,
      ext_caller_contract_id: nil,
      parent_contract_id: encode_contract(parent_pk)
    }
  end

  defp render_remote_log_fields(state, ext_ct_pk) do
    ext_ct_txi = Origin.tx_index!(state, {:contract, ext_ct_pk})
    ext_ct_tx_hash = Enc.encode(:tx_hash, Txs.txi_to_hash(state, ext_ct_txi))

    %{
      ext_caller_contract_txi: ext_ct_txi,
      ext_caller_contract_tx_hash: ext_ct_tx_hash,
      ext_caller_contract_id: encode_contract(ext_ct_pk),
      parent_contract_id: nil
    }
  end

  defp maybe_encode_base64(data) do
    if String.valid?(data), do: data, else: Base.encode64(data)
  end

  defp format_args("Allowance", [account1, account2, <<amount::256>>], %{aexn_args?: true}) do
    [encode_account(account1), encode_account(account2), amount]
  end

  defp format_args("Approval", [account1, account2, <<token_id::256>>, enable], %{
         aexn_args?: true
       })
       when enable in ["true", "false"] do
    [encode_account(account1), encode_account(account2), token_id, enable]
  end

  defp format_args("ApprovalForAll", [account1, account2, enable], %{aexn_args?: true})
       when enable in ["true", "false"] do
    [encode_account(account1), encode_account(account2), enable]
  end

  defp format_args(event_name, [account, <<token_id::256>>], %{aexn_args?: true})
       when event_name in ["Burn", "Mint", "Swap"] do
    [encode_account(account), token_id]
  end

  defp format_args("PairCreated", [pair_pk, token1, token2], %{aexn_args?: true}) do
    [encode_contract(pair_pk), encode_contract(token1), encode_contract(token2)]
  end

  defp format_args("Transfer", [from, to, <<token_id::256>>], %{aexn_args?: true}) do
    [encode_account(from), encode_account(to), token_id]
  end

  defp format_args(
         "TemplateMint",
         [account, <<template_id::256>>, <<token_id::256>>],
         %{aexn_args?: true}
       ) do
    [encode_account(account), template_id, token_id]
  end

  defp format_args(
         "TemplateMint",
         [account, <<template_id::256>>, <<token_id::256>>, edition_serial],
         %{aexn_args?: true}
       ) do
    [encode_account(account), template_id, token_id, edition_serial]
  end

  defp format_args(event_name, args, %{custom_args?: true}) do
    case :persistent_term.get({__MODULE__, event_name}, nil) do
      nil ->
        Enum.map(args, fn <<topic::256>> -> to_string(topic) end)

      custom_args_config ->
        encode_custom_args(args, custom_args_config)
    end
  end

  defp format_args(_event_name, args, _format_opts) do
    Enum.map(args, fn <<topic::256>> -> to_string(topic) end)
  end

  defp encode_custom_args(args, custom_args_config) do
    Enum.with_index(args, fn arg, i ->
      case Map.get(custom_args_config, i) do
        nil ->
          <<topic::256>> = arg
          to_string(topic)

        type ->
          Enc.encode(type, arg)
      end
    end)
  end

  defp get_custom_event_name(event_hash) do
    :persistent_term.get({__MODULE__, event_hash}, nil)
  end

  defp encode_contract(pk), do: Enc.encode(:contract_pubkey, pk)

  defp encode_account(pk), do: Enc.encode(:account_pubkey, pk)

  defp serialize_logs_cursor({create_txi, call_txi, log_idx}),
    do: Base.hex_encode32("#{create_txi}$#{call_txi}$#{log_idx}", padding: false)

  defp deserialize_logs_cursor(nil), do: nil

  defp deserialize_logs_cursor(cursor_bin) do
    with {:ok, decoded_cursor} <- Base.hex_decode32(cursor_bin, padding: false),
         [create_txi_bin, call_txi_bin, log_idx_bin] <-
           String.split(decoded_cursor, "$"),
         {:ok, create_txi} <- deserialize_cursor_int(create_txi_bin),
         {:ok, call_txi} <- deserialize_cursor_int(call_txi_bin),
         {:ok, log_idx} <- deserialize_cursor_int(log_idx_bin) do
      {create_txi, call_txi, log_idx}
    else
      _invalid_cursor -> nil
    end
  end

  defp serialize_calls_cursor({call_txi, local_idx, create_txi, pk, fname, pos}) do
    pk = Base.encode32(pk, padding: false)
    fname = Base.encode32(fname, padding: false)

    Base.hex_encode32("#{call_txi}$#{local_idx}$#{create_txi}$#{pk}$#{fname}$#{pos}",
      padding: false
    )
  end

  defp deserialize_calls_cursor(nil), do: nil

  defp deserialize_calls_cursor(cursor_bin) do
    with {:ok, decoded_cursor} <- Base.hex_decode32(cursor_bin, padding: false),
         [call_txi_bin, local_idx_bin, create_txi_bin, pk_bin, fname_bin, pos_bin] <-
           String.split(decoded_cursor, "$"),
         {:ok, call_txi} <- deserialize_cursor_int(call_txi_bin),
         {:ok, local_idx} <- deserialize_cursor_int(local_idx_bin),
         {:ok, create_txi} <- deserialize_cursor_int(create_txi_bin),
         {:ok, pk} <- deserialize_cursor_string(pk_bin),
         {:ok, fname} <- deserialize_cursor_string(fname_bin),
         {:ok, pos} <- deserialize_cursor_int(pos_bin) do
      {call_txi, local_idx, create_txi, pk, fname, pos}
    else
      _invalid_cursor -> nil
    end
  end

  defp deserialize_cursor_int(txi_bin) do
    case Integer.parse(txi_bin) do
      {txi, ""} -> {:ok, txi}
      _error -> :error
    end
  end

  defp deserialize_cursor_string(event_hash_bin),
    do: Base.decode32(event_hash_bin, padding: false)

  # local_idx is an integer >= -1 (adding 1 to shift to use positive numbers)
  defp serialize_contracts_cursor({txi, local_idx}), do: "#{txi}-#{local_idx + 1}"

  defp deserialize_contracts_cursor(nil), do: {:ok, nil}

  defp deserialize_contracts_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [txi_bin, idx_bin] -> {:ok, {String.to_integer(txi_bin), String.to_integer(idx_bin) - 1}}
      _invalid_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end
end
