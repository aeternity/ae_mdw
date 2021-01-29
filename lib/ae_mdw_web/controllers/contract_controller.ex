defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Db.Model
  alias AeMdw.{Db, Validate}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  ##########

  def stream_plug_hook(%Plug.Conn{path_info: ["contracts", "logs" | rem]} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    P.handle_assign(
      conn,
      (rem == [] && {:ok, {:txi, last_txi()..0}}) || P.parse_scope(rem, ["gen", "txi"]),
      P.parse_offset(conn.params),
      {:ok, %{}}
    )
  end

  ##########

  def logs(conn, _params),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  ##########

  def db_stream(:logs, params, scope) do
    alias DBS.Resource.Util, as: RU

    {{start_txi, _} = {l, r}, dir, succ} = progress(scope)

    scope_checker = scope_checker(dir, {l, r})

    {tab, init_key, key_tester} = search_context!(params, start_txi, scope_checker, limit(dir))

    advance = RU.advance_signal_fn(succ, key_tester)

    RU.signalled_resource({{:skip, init_key}, advance}, tab, fn m_obj ->
      index = elem(m_obj, 1)
      Db.Format.to_map(normalize_key(index, tab), Model.ContractLog)
    end)
  end

  def normalize_key({create_txi, call_txi, event_hash, log_idx}, Model.ContractLog),
    do: {create_txi, call_txi, event_hash, log_idx}

  def normalize_key({_data, call_txi, create_txi, event_hash, log_idx}, Model.DataContractLog),
    do: {create_txi, call_txi, event_hash, log_idx}

  def normalize_key({event_hash, call_txi, create_txi, log_idx}, Model.EvtContractLog),
    do: {create_txi, call_txi, event_hash, log_idx}

  def normalize_key({call_txi, create_txi, event_hash, log_idx}, Model.IdxContractLog),
    do: {create_txi, call_txi, event_hash, log_idx}

  ##########

  def height_txi(h) when is_integer(h) and h >= 0,
    do: Model.block(read_block!({h, -1}), :tx_index)

  def height_txi({f, l}) when f < l,
    do: {height_txi(f), (l >= last_gen() && last_txi()) || height_txi(l + 1)}

  def height_txi({f, l}) when f > l,
    do: {(f >= last_gen() && last_txi()) || height_txi(f + 1), height_txi(l)}

  def height_txi({x, x}),
    do: {height_txi(x), (x >= last_gen() && last_txi()) || height_txi(x + 1)}

  def progress({:txi, %Range{first: f, last: l}}) when f <= l, do: {{f, l}, :forward, &next/2}
  def progress({:txi, %Range{first: f, last: l}}) when f > l, do: {{f, l}, :backward, &prev/2}

  def progress({:gen, %Range{first: f, last: l}}) do
    {dir, fun} = (f <= l && {:forward, &next/2}) || {:backward, &prev/2}
    {height_txi({f, l}), dir, fun}
  end

  def min(:create_txi), do: -10
  def min(:data_prefix), do: <<>>
  def min(:event_hash), do: <<>>
  def min(:log_idx), do: -1

  def max(:create_txi), do: max_256bit_int()
  def max(:data_prefix), do: AeMdw.Node.max_blob()
  def max(:event_hash), do: <<max_256bit_int()::256>>
  def max(:log_idx), do: max_256bit_int()

  def convert({"contract_id", [contract_id]}),
    do: [create_txi: create_txi!(contract_id)]

  def convert({"data", [data]}),
    do: [data_prefix: URI.decode(data)]

  def convert({"event", [constructor_name]}),
    do: [event_hash: :aec_hash.blake2b_256_hash(constructor_name)]

  def convert(other),
    do: raise(ErrInput.Query, value: other)

  def limit(:forward), do: &min/1
  def limit(:backward), do: &max/1

  def scope_checker(:forward, {f, l}), do: fn x -> x >= f && x <= l end
  def scope_checker(:backward, {f, l}), do: fn x -> x >= l && x <= f end

  def prefix_checker(prefix) do
    prefix_size = :erlang.size(prefix)

    fn data ->
      is_binary(data) &&
        :erlang.size(data) >= prefix_size &&
        :binary.part(data, {0, prefix_size}) == prefix
    end
  end

  def search_context!(%{} = params, start_txi, scope_checker, limit_fn) do
    params
    |> Enum.to_list()
    |> Enum.sort()
    |> Enum.flat_map(&convert/1)
    |> search_context!(start_txi, scope_checker, limit_fn)
  end

  def search_context!(
        [create_txi: create_txi, data_prefix: data_prefix, event_hash: event_hash],
        start_txi,
        scope_checker,
        limit
      ) do
    data_checker = prefix_checker(data_prefix)
    event_checker = prefix_checker(event_hash)

    {Model.DataContractLog,
     {data_prefix <> limit.(:data_prefix), start_txi, create_txi, event_hash, limit.(:log_idx)},
     fn {data, call_txi, ct_txi, event, _log_idx} ->
       case data_checker.(data) && scope_checker.(call_txi) do
         true -> (ct_txi == create_txi && event_checker.(event)) || :skip
         false -> false
       end
     end}
  end

  def search_context!(
        [create_txi: create_txi, data_prefix: data_prefix],
        start_txi,
        scope_checker,
        limit
      ) do
    data_checker = prefix_checker(data_prefix)

    {Model.DataContractLog,
     {data_prefix <> limit.(:data_prefix), start_txi, create_txi, limit.(:event_hash),
      limit.(:log_idx)},
     fn {data, call_txi, ct_txi, _event, _log_idx} ->
       case data_checker.(data) && scope_checker.(call_txi) do
         true -> ct_txi == create_txi || :skip
         false -> false
       end
     end}
  end

  def search_context!(
        [create_txi: create_txi, event_hash: event_hash],
        start_txi,
        scope_checker,
        limit
      ) do
    event_checker = prefix_checker(event_hash)

    {Model.EvtContractLog, {event_hash, start_txi, create_txi, limit.(:log_idx)},
     fn {event, call_txi, ct_txi, _} ->
       case event_checker.(event) && scope_checker.(call_txi) do
         true -> ct_txi == create_txi || :skip
         false -> false
       end
     end}
  end

  def search_context!(
        [data_prefix: data_prefix, event_hash: event_hash],
        start_txi,
        scope_checker,
        limit
      ) do
    data_checker = prefix_checker(data_prefix)
    event_checker = prefix_checker(event_hash)

    {Model.DataContractLog,
     {data_prefix <> limit.(:data_prefix), start_txi, limit.(:create_txi), event_hash,
      limit.(:log_idx)},
     fn {data, call_txi, _ct_txi, event, _log_idx} ->
       case data_checker.(data) && scope_checker.(call_txi) do
         true -> event_checker.(event) || :skip
         false -> false
       end
     end}
  end

  def search_context!([create_txi: create_txi], start_txi, _scope_checker, limit) do
    {Model.ContractLog, {create_txi, start_txi, limit.(:event_hash), limit.(:log_idx)},
     fn {ct_txi, _start_txi, _event, _log_idx} -> ct_txi == create_txi end}
  end

  def search_context!([data_prefix: data_prefix], start_txi, scope_checker, limit) do
    data_checker = prefix_checker(data_prefix)

    {Model.DataContractLog,
     {data_prefix <> limit.(:data_prefix), start_txi, limit.(:create_txi), limit.(:event_hash),
      limit.(:log_idx)},
     fn {data, call_txi, _ct_txi, _event, _log_idx} ->
       data_checker.(data) && scope_checker.(call_txi)
     end}
  end

  def search_context!([event_hash: event_hash], start_txi, scope_checker, limit) do
    event_checker = prefix_checker(event_hash)

    {Model.EvtContractLog, {event_hash, start_txi, limit.(:create_txi), limit.(:log_idx)},
     fn {event, call_txi, _, _} -> event_checker.(event) && scope_checker.(call_txi) end}
  end

  def search_context!([], start_txi, scope_checker, limit) do
    {Model.IdxContractLog,
     {start_txi, limit.(:create_txi), limit.(:event_hash), limit.(:log_idx)},
     fn {call_txi, _, _, _} -> scope_checker.(call_txi) end}
  end

  def search_context!(params),
    do: raise(ErrInput.Query, value: params)

  def tx_id!(enc_tx_hash) do
    ok_nil(:aeser_api_encoder.safe_decode(:tx_hash, enc_tx_hash)) ||
      raise ErrInput.Id, value: enc_tx_hash
  end

  def create_txi!(contract_id) do
    pk = Validate.id!(contract_id)
    (pk == Db.Sync.Contract.migrate_contract_pk() && -1) || Db.Origin.tx_index({:contract, pk})
  end
end
