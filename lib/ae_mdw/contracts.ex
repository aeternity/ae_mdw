defmodule AeMdw.Contracts do
  @moduledoc """
  Context module for dealing with Contracts.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

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

  @pagination_params ~w(limit cursor rev direction scope tx_hash)

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

      {prev_cursor, contract_keys, next_cursor} =
        fn direction ->
          ~w(contract_create_tx ga_attach_tx)a
          |> Enum.map(fn tx_type ->
            state
            |> DBUtil.transactions_of_type(tx_type, direction, scope, cursor)
            |> Stream.map(&{&1, tx_type})
          end)
          |> Collection.merge(direction)
        end
        |> Collection.paginate(pagination)

      contracts = Enum.map(contract_keys, &render_contract(state, &1))

      {:ok,
       {serialize_contracts_cursor(prev_cursor), contracts,
        serialize_contracts_cursor(next_cursor)}}
    end
  end

  @spec fetch_logs(State.t(), pagination(), range(), query(), cursor()) ::
          {:ok, cursor(), [log()], cursor()} | {:error, reason()}
  def fetch_logs(state, pagination, range, query, cursor) do
    cursor = deserialize_logs_cursor(cursor)
    scope = deserialize_scope(state, range)

    try do
      {prev_cursor, logs, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Map.new(&convert_param(state, &1))
        |> build_logs_pagination(state, scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_logs_cursor(prev_cursor), logs, serialize_logs_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  @spec fetch_calls(State.t(), pagination(), range(), query(), cursor()) ::
          {:ok, cursor(), [call()], cursor()} | {:error, reason()}
  def fetch_calls(state, pagination, range, query, cursor) do
    cursor = deserialize_calls_cursor(cursor)
    scope = deserialize_scope(state, range)

    try do
      {prev_cursor, calls, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Map.new(&convert_param(state, &1))
        |> build_calls_pagination(state, scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_calls_cursor(prev_cursor), Enum.map(calls, &render_call(state, &1)),
       serialize_calls_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
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
         {:ok, txi} when txi >= 0 <- Origin.tx_index(state, {:contract, pubkey}) do
      Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
      signed_tx = Db.get_signed_tx(tx_hash)
      {outer_tx_type, _tx} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))

      {txi_idx, tx_type} =
        if outer_tx_type == :contract_call_tx do
          local_idx =
            ~w(Chain.create Chain.clone Call.create Call.clone)
            |> Enum.map(&fetch_int_contract_calls(state, txi, &1))
            |> Stream.concat()
            |> Enum.find_value(fn Model.int_contract_call(index: {^txi, local_idx}) ->
              create_tx = DBUtil.read_node_tx(state, {txi, local_idx})

              :aect_create_tx.contract_pubkey(create_tx) == pubkey && local_idx
            end)

          {{txi, local_idx}, :contract_create_tx}
        else
          {{txi, -1}, outer_tx_type}
        end

      {:ok, render_contract(state, {txi_idx, tx_type})}
    else
      {:error, reason} -> {:error, reason}
      _preset_or_not_found -> {:error, ErrInput.NotFound.exception(value: contract_id)}
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
      state
      |> Collection.stream(@contract_log_table, direction, key_boundary, cursor)
      |> Stream.map(fn {create_txi, call_txi, log_idx} ->
        {create_txi, call_txi, log_idx}
      end)
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

  defp build_calls_pagination(query, _scope, _state, _cursor),
    do: raise(ErrInput.Query, value: query)

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

  defp convert_param(state, {"contract_id", contract_id}),
    do: {:create_txi, create_txi!(state, contract_id)}

  defp convert_param(state, {"contract", contract_id}),
    do: {:create_txi, create_txi!(state, contract_id)}

  defp convert_param(_state, {"data", data}), do: {:data_prefix, URI.decode(data)}

  defp convert_param(_state, {"event", ctor_name}),
    do: {:event_hash, :aec_hash.blake2b_256_hash(ctor_name)}

  defp convert_param(_state, {"function", fname}) when byte_size(fname) > 0, do: {:fname, fname}

  defp convert_param(state, {"function_prefix", fname}),
    do: convert_param(state, {"function", fname})

  defp convert_param(_state, {"aexn-args", _}), do: {:ignore, nil}

  defp convert_param(_state, {id_key, id_val}) do
    pos_types =
      id_key
      |> Parser.parse_field()
      |> Enum.flat_map(fn {tx_type, positions} -> Enum.map(positions, &{&1, tx_type}) end)
      |> Enum.group_by(fn {pos, _tx_type} -> pos end, fn {_pos, tx_type} -> tx_type end)

    {:type_pos, {pos_types, Validate.id!(id_val)}}
  end

  defp convert_param(_state, other), do: raise(ErrInput.Query, value: other)

  defp deserialize_scope(_state, nil), do: {@min_txi, @max_txi}

  defp deserialize_scope(state, {:gen, first_gen..last_gen}) do
    first = DBUtil.gen_to_txi(state, first_gen)
    last = DBUtil.gen_to_txi(state, last_gen + 1) - 1
    deserialize_scope(state, {:txi, first..last})
  end

  defp deserialize_scope(_state, {:txi, first_txi..last_txi}), do: {first_txi, last_txi}

  defp create_txi!(state, contract_id) do
    pk = Validate.id!(contract_id)

    case Origin.tx_index(state, {:contract, pk}) do
      {:ok, txi} -> txi
      :not_found -> raise ErrInput.Id, value: contract_id
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

  defp render_call(state, {call_txi, local_idx, _create_txi, _pk, _fname, _pos}) do
    call_key = {call_txi, local_idx}
    Format.to_map(state, call_key, @int_contract_call_table)
  end

  defp render_contract(state, {create_txi_idx, tx_type}) do
    {create_tx, _inner_tx_type, tx_hash, source_tx_type, block_hash} =
      DBUtil.read_node_tx_details(state, create_txi_idx)

    {contract_pk, encoded_tx} =
      case tx_type do
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
      contract: Enc.encode(:contract_pubkey, contract_pk),
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(source_tx_type),
      create_tx: encoded_tx
    }
  end

  defp serialize_logs_cursor(nil), do: nil

  defp serialize_logs_cursor({{create_txi, call_txi, log_idx}, is_reversed?}) do
    {Base.hex_encode32("#{create_txi}$#{call_txi}$#{log_idx}",
       padding: false
     ), is_reversed?}
  end

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

  defp serialize_calls_cursor(nil), do: nil

  defp serialize_calls_cursor({{call_txi, local_idx, create_txi, pk, fname, pos}, is_reversed?}) do
    pk = Base.encode32(pk, padding: false)
    fname = Base.encode32(fname, padding: false)

    {
      Base.hex_encode32("#{call_txi}$#{local_idx}$#{create_txi}$#{pk}$#{fname}$#{pos}",
        padding: false
      ),
      is_reversed?
    }
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

  defp serialize_contracts_cursor(nil), do: nil

  # local_idx is an integer >= -1 (adding 1 to shift to use positive numbers)
  defp serialize_contracts_cursor({{{txi, local_idx}, _tx_type}, is_reversed?}),
    do: {"#{txi}-#{local_idx + 1}", is_reversed?}

  defp deserialize_contracts_cursor(nil), do: {:ok, nil}

  defp deserialize_contracts_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [txi_bin, idx_bin] -> {:ok, {String.to_integer(txi_bin), String.to_integer(idx_bin) - 1}}
      _invalid_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end
end
