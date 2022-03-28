defmodule AeMdw.Contracts do
  @moduledoc """
  Context module for dealing with Contracts.
  """

  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Database
  alias AeMdw.Db.Origin
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type log() :: map()
  @type call() :: map()
  @type cursor() :: binary() | nil
  @type query() :: %{binary() => binary()}
  @type local_idx() :: non_neg_integer()
  @type log_key() :: {create_txi(), local_idx()}
  @type event_hash() :: binary()
  @type log_idx() :: non_neg_integer()
  @type call_key() :: {create_txi(), txi(), event_hash(), log_idx()}

  @typep txi() :: Txs.txi()
  @typep create_txi() :: txi() | -1
  @typep reason() :: binary()
  @typep pagination() :: Collection.direction_limit()
  @typep range() :: {:gen, Range.t()} | {:txi, Range.t()} | nil

  @contract_log_table Model.ContractLog
  @idx_contract_log_table Model.IdxContractLog
  @evt_contract_log_table Model.EvtContractLog
  @data_contract_log_table Model.DataContractLog
  @int_contract_call_table Model.IntContractCall
  @grp_int_contract_call_table Model.GrpIntContractCall
  @fname_int_contract_call_table Model.FnameIntContractCall
  @id_int_contract_call_table Model.IdIntContractCall
  @grp_id_int_contract_call_table Model.GrpIdIntContractCall

  @pagination_params ~w(limit cursor rev direction scope)

  @max_256bit_int Util.max_256bit_int()
  @max_256bit_bin Util.max_256bit_bin()
  @min_int Util.min_int()
  @min_bin Util.min_bin()

  @spec fetch_logs(pagination(), range(), query(), cursor()) ::
          {:ok, cursor(), [log()], cursor()} | {:error, reason()}
  def fetch_logs(pagination, range, query, cursor) do
    cursor = deserialize_logs_cursor(cursor)
    scope = deserialize_logs_scope(range)

    try do
      {prev_cursor, logs, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_logs_pagination(scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_logs_cursor(prev_cursor), Enum.map(logs, &render_log/1),
       serialize_logs_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  @spec fetch_calls(pagination(), range(), query(), cursor()) ::
          {:ok, cursor(), [call()], cursor()} | {:error, reason()}
  def fetch_calls(pagination, range, query, cursor) do
    cursor = deserialize_calls_cursor(cursor)
    scope = deserialize_calls_scope(range)

    try do
      {prev_cursor, calls, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.map(&convert_param/1)
        |> Enum.sort()
        |> build_calls_pagination(scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_calls_cursor(prev_cursor), Enum.map(calls, &render_call/1),
       serialize_calls_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  @spec fetch_int_contract_calls(Txs.txi(), Contract.fname()) :: Enumerable.t()
  def fetch_int_contract_calls(txi, fname) do
    @int_contract_call_table
    |> Collection.stream({txi, @min_int})
    |> Stream.take_while(fn {call_txi, _local_txi} -> call_txi == txi end)
    |> Stream.map(&Database.fetch!(@int_contract_call_table, &1))
    |> Stream.filter(&match?(Model.int_contract_call(fname: ^fname), &1))
  end

  defp build_logs_pagination(%{data_prefix: data_prefix}, scope, cursor) do
    {{first_create_txi, first_call_txi, _first_event_hash, _first_log_idx, first_data},
     {last_create_txi, last_call_txi, _last_event_hash, _last_log_idx, last_data}} = scope

    scope =
      {{data_prefix <> first_data, first_call_txi, first_create_txi, nil, nil},
       {data_prefix <> last_data, last_call_txi, last_create_txi, nil, nil}}

    cursor =
      case cursor do
        nil ->
          nil

        {create_txi, call_txi, event_hash, log_idx, data} ->
          {data, call_txi, create_txi, event_hash, log_idx}
      end

    fn direction ->
      @data_contract_log_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {data, call_txi, create_txi, event_hash, log_idx} ->
        {create_txi, call_txi, event_hash, log_idx, data}
      end)
    end
  end

  defp build_logs_pagination(%{create_txi: create_txi}, scope, cursor) do
    {{_first_create_txi, first_call_txi, first_event_hash, _first_log_idx, _first_data},
     {_last_create_txi, last_call_txi, last_event_hash, _last_log_idx, _last_data}} = scope

    scope =
      {{create_txi, first_call_txi, first_event_hash, nil},
       {create_txi, last_call_txi, last_event_hash, nil}}

    cursor =
      case cursor do
        nil ->
          nil

        {create_txi, call_txi, event_hash, log_idx, _data} ->
          {create_txi, call_txi, event_hash, log_idx}
      end

    fn direction ->
      @contract_log_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {create_txi, call_txi, even_hash, log_idx} ->
        {create_txi, call_txi, even_hash, log_idx, @min_bin}
      end)
    end
  end

  defp build_logs_pagination(%{event_hash: event_hash}, scope, cursor) do
    {{first_create_txi, first_call_txi, _first_event_hash, _first_log_idx, _first_data},
     {last_create_txi, last_call_txi, _last_event_hash, _last_log_idx, _last_data}} = scope

    scope =
      {{event_hash, first_call_txi, first_create_txi, nil},
       {event_hash, last_call_txi, last_create_txi, nil}}

    cursor =
      case cursor do
        nil ->
          nil

        {create_txi, call_txi, event_hash, log_idx, _data} ->
          {event_hash, call_txi, create_txi, log_idx}
      end

    fn direction ->
      @evt_contract_log_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {event_hash, call_txi, create_txi, log_idx} ->
        {create_txi, call_txi, event_hash, log_idx, @min_bin}
      end)
    end
  end

  defp build_logs_pagination(_query, scope, cursor) do
    {{first_create_txi, first_call_txi, first_event_hash, first_log_idx, _first_data},
     {last_create_txi, last_call_txi, last_event_hash, last_log_idx, _last_data}} = scope

    scope =
      {{first_call_txi, first_create_txi, first_event_hash, first_log_idx},
       {last_call_txi, last_create_txi, last_event_hash, last_log_idx}}

    cursor =
      case cursor do
        nil ->
          nil

        {create_txi, call_txi, event_hash, log_idx, _data} ->
          {call_txi, create_txi, event_hash, log_idx}
      end

    fn direction ->
      @idx_contract_log_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {call_txi, create_txi, event_hash, log_idx} ->
        {create_txi, call_txi, event_hash, log_idx, @min_bin}
      end)
    end
  end

  defp build_calls_pagination([fname: fname_prefix], scope, cursor) do
    {{first_call_txi, _first_local_idx, _first_create_txi, _first_pk, first_fname, _first_pos},
     {last_call_txi, _last_local_idx, _last_create_txi, _last_pk, last_fname, _last_pos}} = scope

    scope =
      {{fname_prefix <> first_fname, first_call_txi, nil},
       {fname_prefix <> last_fname, last_call_txi, nil}}

    cursor =
      case cursor do
        nil -> nil
        {call_txi, local_idx, _create_txi, _pk, fname, _pos} -> {fname, call_txi, local_idx}
      end

    fn direction ->
      @fname_int_contract_call_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {fname, call_txi, local_idx} ->
        {call_txi, local_idx, @min_int, @min_bin, fname, @min_int}
      end)
    end
  end

  defp build_calls_pagination([create_txi: create_txi], scope, cursor) do
    {{first_call_txi, first_local_idx, _first_create_txi, _first_pk, _first_fname, _first_pos},
     {last_call_txi, last_local_idx, _last_create_txi, _last_pk, _last_fname, _last_pos}} = scope

    scope =
      {{create_txi, first_call_txi, first_local_idx}, {create_txi, last_call_txi, last_local_idx}}

    cursor =
      case cursor do
        nil -> nil
        {call_txi, local_idx, _create_txi, _pk, _fname, _pos} -> {create_txi, call_txi, local_idx}
      end

    fn direction ->
      @grp_int_contract_call_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {create_txi, call_txi, local_idx} ->
        {call_txi, local_idx, create_txi, @min_bin, @min_bin, @min_int}
      end)
    end
  end

  defp build_calls_pagination([], scope, cursor) do
    {{first_call_txi, first_local_idx, _first_create_txi, _first_pk, _first_fname, _first_pos},
     {last_call_txi, last_local_idx, _last_create_txi, _last_pk, _last_fname, _last_pos}} = scope

    scope = {{first_call_txi, first_local_idx}, {last_call_txi, last_local_idx}}

    cursor =
      case cursor do
        nil -> nil
        {call_txi, local_idx, _create_txi, _pk, _fname, _pos} -> {call_txi, local_idx}
      end

    fn direction ->
      @int_contract_call_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {call_txi, local_idx} ->
        {call_txi, local_idx, @min_int, @min_bin, @min_bin, @min_int}
      end)
    end
  end

  defp build_calls_pagination([create_txi: create_txi, type_pos: {pos_types, pk}], scope, cursor) do
    {{first_call_txi, first_local_idx, _first_create_txi, _first_pk, _first_fname, _first_pos},
     {last_call_txi, last_local_idx, _last_create_txi, _last_pk, _last_fname, _last_pos}} = scope

    collections =
      Enum.map(pos_types, fn {tx_pos, tx_types} ->
        cursor =
          case cursor do
            nil ->
              nil

            {call_txi, local_idx, _create_txi, _pk, _fname, _pos} ->
              {create_txi, pk, tx_pos, call_txi, local_idx}
          end

        scope =
          {{create_txi, pk, tx_pos, first_call_txi, first_local_idx},
           {create_txi, pk, tx_pos, last_call_txi, last_local_idx}}

        {scope, cursor, tx_types}
      end)

    fn direction ->
      collections
      |> Enum.map(fn {scope, cursor, tx_types} ->
        build_grp_id_calls_stream(direction, scope, cursor, tx_types)
      end)
      |> Collection.merge(direction)
      |> Stream.map(fn {create_txi, pk, call_txi, local_idx, pos} ->
        {call_txi, local_idx, create_txi, pk, @min_bin, pos}
      end)
    end
  end

  defp build_calls_pagination([type_pos: {pos_types, pk}], scope, cursor) do
    {{first_call_txi, first_local_idx, _first_create_txi, _first_pk, _first_fname, _first_pos},
     {last_call_txi, last_local_idx, _last_create_txi, _last_pk, _last_fname, _last_pos}} = scope

    collections =
      Enum.map(pos_types, fn {tx_pos, tx_types} ->
        cursor =
          case cursor do
            nil ->
              nil

            {call_txi, local_idx, _create_txi, _pk, _fname, _pos} ->
              {pk, tx_pos, call_txi, local_idx}
          end

        scope =
          {{pk, tx_pos, first_call_txi, first_local_idx},
           {pk, tx_pos, last_call_txi, last_local_idx}}

        {scope, cursor, tx_types}
      end)

    fn direction ->
      collections
      |> Enum.map(fn {scope, cursor, tx_types} ->
        build_id_int_call_stream(direction, scope, cursor, tx_types)
      end)
      |> Collection.merge(direction)
      |> Stream.map(fn {pk, call_txi, local_idx, pos} ->
        {call_txi, local_idx, @min_int, pk, @min_bin, pos}
      end)
    end
  end

  defp build_calls_pagination(_query, _scope, _cursor),
    do: raise(ErrInput.Query, value: %{})

  defp build_grp_id_calls_stream(direction, scope, cursor, tx_types) do
    @grp_id_int_contract_call_table
    |> Collection.stream(direction, scope, cursor)
    |> Stream.filter(fn {_create_txi, _pk, _pos, call_txi, local_idx} ->
      Enum.member?(tx_types, fetch_tx_type(call_txi, local_idx))
    end)
    |> Stream.map(fn {create_txi, pk, pos, call_txi, local_idx} ->
      {create_txi, pk, call_txi, local_idx, pos}
    end)
  end

  defp build_id_int_call_stream(direction, scope, cursor, tx_types) do
    @id_int_contract_call_table
    |> Collection.stream(direction, scope, cursor)
    |> Stream.filter(fn {_pk, _pos, call_txi, local_idx} ->
      {tx_type, _tx} =
        Model.IntContractCall
        |> Database.fetch!({call_txi, local_idx})
        |> Model.int_contract_call(:tx)
        |> :aetx.specialize_type()

      Enum.member?(tx_types, tx_type)
    end)
    |> Stream.map(fn {pk, pos, call_txi, local_idx} ->
      {pk, call_txi, local_idx, pos}
    end)
  end

  defp convert_param({"contract_id", contract_id}), do: {:create_txi, create_txi!(contract_id)}
  defp convert_param({"data", data}), do: {:data_prefix, URI.decode(data)}

  defp convert_param({"event", ctor_name}),
    do: {:event_hash, :aec_hash.blake2b_256_hash(ctor_name)}

  defp convert_param({"function", fun_name}), do: {:fname, fun_name}

  defp convert_param({id_key, id_val}) do
    pos_types =
      id_key
      |> Parser.parse_field()
      |> Enum.flat_map(fn {tx_type, positions} -> Enum.map(positions, &{&1, tx_type}) end)
      |> Enum.group_by(fn {pos, _tx_type} -> pos end, fn {_pos, tx_type} -> tx_type end)

    {:type_pos, {pos_types, Validate.id!(id_val)}}
  end

  defp convert_param(other), do: raise(ErrInput.Query, value: other)

  defp deserialize_logs_scope(nil) do
    {{@min_int, @min_int, @min_bin, @min_int, @min_bin},
     {@max_256bit_int, @max_256bit_int, max_blob(), @max_256bit_int, max_blob()}}
  end

  defp deserialize_logs_scope({:gen, %Range{first: first_gen, last: last_gen}}) do
    deserialize_logs_scope(
      {:txi,
       %Range{
         first: DBUtil.gen_to_txi(first_gen),
         last: DBUtil.gen_to_txi(last_gen + 1) - 1
       }}
    )
  end

  defp deserialize_logs_scope({:txi, %Range{first: first_txi, last: last_txi}}) do
    {{first_txi, @min_int, @min_bin, @min_int, @min_bin},
     {last_txi, @max_256bit_int, max_blob(), @max_256bit_int, max_blob()}}
  end

  defp deserialize_calls_scope(nil) do
    {{@min_int, @min_int, @min_int, @min_bin, @min_bin, @min_int},
     {@max_256bit_int, @max_256bit_int, @max_256bit_int, @max_256bit_bin, max_blob(),
      @max_256bit_int}}
  end

  defp deserialize_calls_scope({:gen, %Range{first: first_gen, last: last_gen}}) do
    deserialize_calls_scope(
      {:txi,
       %Range{
         first: DBUtil.gen_to_txi(first_gen),
         last: DBUtil.gen_to_txi(last_gen + 1) - 1
       }}
    )
  end

  defp deserialize_calls_scope({:txi, %Range{first: first_txi, last: last_txi}}) do
    {{first_txi, @min_int, @min_int, @min_bin, @min_bin, @min_int},
     {last_txi, @max_256bit_int, @max_256bit_int, @max_256bit_bin, max_blob(), @max_256bit_int}}
  end

  defp create_txi!(contract_id) do
    pk = Validate.id!(contract_id)

    case Origin.tx_index({:contract, pk}) do
      {:ok, txi} -> txi
      :not_found -> raise ErrInput.Id, value: contract_id
    end
  end

  defp fetch_tx_type(call_txi, local_idx) do
    {tx_type, _tx} =
      Model.IntContractCall
      |> Database.fetch!({call_txi, local_idx})
      |> Model.int_contract_call(:tx)
      |> :aetx.specialize_type()

    tx_type
  end

  defp render_log({create_txi, call_txi, event_hash, log_idx, _data}) do
    log_key = {create_txi, call_txi, event_hash, log_idx}

    Format.to_map(log_key, @contract_log_table)
  end

  defp render_call({call_txi, local_idx, _create_txi, _pk, _fname, _pos}) do
    call_key = {call_txi, local_idx}
    Format.to_map(call_key, @int_contract_call_table)
  end

  defp serialize_logs_cursor(nil), do: nil

  defp serialize_logs_cursor({{create_txi, call_txi, event_hash, log_idx, data}, is_reversed?}) do
    event_hash = Base.encode32(event_hash)
    data = URI.encode(data)

    {Base.hex_encode32("#{create_txi}$#{call_txi}$#{event_hash}$#{log_idx}$#{data}",
       padding: false
     ), is_reversed?}
  end

  defp deserialize_logs_cursor(nil), do: nil

  defp deserialize_logs_cursor(cursor_bin) do
    with {:ok, decoded_cursor} <- Base.hex_decode32(cursor_bin, padding: false),
         [create_txi_bin, call_txi_bin, event_hash_bin, log_idx_bin, data_bin] <-
           String.split(decoded_cursor, "$"),
         {:ok, create_txi} <- deserialize_cursor_int(create_txi_bin),
         {:ok, call_txi} <- deserialize_cursor_int(call_txi_bin),
         {:ok, event_hash} <- deserialize_cursor_string(event_hash_bin),
         {:ok, log_idx} <- deserialize_cursor_int(log_idx_bin),
         {:ok, data} <- deserialize_cursor_data(data_bin) do
      {create_txi, call_txi, event_hash, log_idx, data}
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

  defp deserialize_cursor_data(data_bin) do
    try do
      {:ok, URI.decode(data_bin)}
    rescue
      ArgumentError -> :error
    end
  end

  defp max_blob(), do: AeMdw.Node.max_blob()
end
