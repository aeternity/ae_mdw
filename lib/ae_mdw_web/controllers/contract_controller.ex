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

  def stream_plug_hook(%Plug.Conn{path_info: ["contracts", _ | rem]} = conn) do
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

  def calls(conn, _params),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  ##########

  def db_stream(:logs, params, scope) do
    alias DBS.Resource.Util, as: RU

    {{start_txi, _} = {l, r}, dir, succ} = progress(scope)
    scope_checker = scope_checker(dir, {l, r})

    {tab, init_key, key_tester} =
      logs_search_context!(params, start_txi, scope_checker, limit(dir))

    advance = RU.advance_signal_fn(succ, key_tester)

    RU.signalled_resource({{:skip, init_key}, advance}, tab, fn m_obj ->
      index = elem(m_obj, 1)
      Db.Format.to_map(normalize_key(index, tab), Model.ContractLog)
    end)
  end

  def db_stream(:calls, params, scope) do
    alias DBS.Resource.Util, as: RU

    {{start_txi, _} = {l, r}, dir, succ} = progress(scope)
    scope_checker = scope_checker(dir, {l, r})

    {tab, init_key, key_tester} =
      calls_search_context!(params, start_txi, scope_checker, limit(dir))

    advance = RU.advance_signal_fn(succ, key_tester)

    RU.signalled_resource({{:skip, init_key}, advance}, tab, fn m_obj ->
      index = elem(m_obj, 1)
      Db.Format.to_map(normalize_key(index, tab), Model.IntContractCall)
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

  def normalize_key({call_txi, local_idx}, Model.IntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_create_txi, call_txi, local_idx}, Model.GrpIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_fname, call_txi, local_idx}, Model.FnameIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_fname, _create_txi, call_txi, local_idx}, Model.FnameGrpIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_pk, _pos, call_txi, local_idx}, Model.IdIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_create_txi, _pk, _pos, call_txi, local_idx}, Model.GrpIdIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key({_pk, _fname, _pos, call_txi, local_idx}, Model.IdFnameIntContractCall),
    do: {call_txi, local_idx}

  def normalize_key(
        {_create_txi, _pk, _fname, _pos, call_txi, local_idx},
        Model.GrpIdFnameIntContractCall
      ),
      do: {call_txi, local_idx}

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
  def min(:fname), do: <<>>
  def min(:local_idx), do: -1

  def max(:create_txi), do: max_256bit_int()
  def max(:data_prefix), do: AeMdw.Node.max_blob()
  def max(:event_hash), do: <<max_256bit_int()::256>>
  def max(:log_idx), do: max_256bit_int()
  def max(:fname), do: AeMdw.Node.max_blob()
  def max(:local_idx), do: max_256bit_int()

  def convert({"contract_id", [contract_id]}), do: [create_txi: create_txi!(contract_id)]
  def convert({"data", [data]}), do: [data_prefix: URI.decode(data)]
  def convert({"event", [ctor_name]}), do: [event_hash: :aec_hash.blake2b_256_hash(ctor_name)]
  def convert({"function", [fun_name]}), do: [fname: fun_name]

  def convert({id_key, [id_val]}),
    do: [{AeMdw.Db.Stream.Query.Parser.parse_field(id_key), Validate.id!(id_val)}]

  # def convert({id_key, [id_val]}),
  #   do: (id_key in AE.id_fields()
  #        && [{{:id, String.to_existing_atom(id_key)}, Validate.id!(id_val)}])
  #       || raise(ErrInput.Query, value: id_key)
  def convert(other), do: raise(ErrInput.Query, value: other)

  def limit(:forward), do: &min/1
  def limit(:backward), do: &max/1

  def scope_checker(:forward, {f, l}), do: fn x -> x >= f && x <= l end
  def scope_checker(:backward, {f, l}), do: fn x -> x >= l && x <= f end

  ##########

  def logs_search_context!(%{} = params, start_txi, scope_checker, limit_fn) do
    params
    |> Enum.to_list()
    |> Enum.sort()
    |> Enum.flat_map(&convert/1)
    |> logs_search_context!(start_txi, scope_checker, limit_fn)
  end

  def logs_search_context!(
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

  def logs_search_context!(
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

  def logs_search_context!(
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

  def logs_search_context!(
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

  def logs_search_context!([create_txi: create_txi], start_txi, _scope_checker, limit) do
    {Model.ContractLog, {create_txi, start_txi, limit.(:event_hash), limit.(:log_idx)},
     fn {ct_txi, _start_txi, _event, _log_idx} -> ct_txi == create_txi end}
  end

  def logs_search_context!([data_prefix: data_prefix], start_txi, scope_checker, limit) do
    data_checker = prefix_checker(data_prefix)

    {Model.DataContractLog,
     {data_prefix <> limit.(:data_prefix), start_txi, limit.(:create_txi), limit.(:event_hash),
      limit.(:log_idx)},
     fn {data, call_txi, _ct_txi, _event, _log_idx} ->
       data_checker.(data) && scope_checker.(call_txi)
     end}
  end

  def logs_search_context!([event_hash: event_hash], start_txi, scope_checker, limit) do
    event_checker = prefix_checker(event_hash)

    {Model.EvtContractLog, {event_hash, start_txi, limit.(:create_txi), limit.(:log_idx)},
     fn {event, call_txi, _, _} -> event_checker.(event) && scope_checker.(call_txi) end}
  end

  def logs_search_context!([], start_txi, scope_checker, limit) do
    {Model.IdxContractLog,
     {start_txi, limit.(:create_txi), limit.(:event_hash), limit.(:log_idx)},
     fn {call_txi, _, _, _} -> scope_checker.(call_txi) end}
  end

  def logs_search_context!(params),
    do: raise(ErrInput.Query, value: params)

  ##########

  def calls_search_context!(%{} = params, start_txi, scope_checker, limit_fn) do
    params
    |> Enum.to_list()
    |> Enum.sort()
    |> Enum.flat_map(&convert/1)
    |> calls_search_context!(start_txi, scope_checker, limit_fn)
  end

  def calls_search_context!(
        [create_txi: create_txi, fname: fname_prefix],
        start_txi,
        scope_checker,
        limit
      ) do
    fname_checker = prefix_checker(fname_prefix)

    {Model.FnameGrpIntContractCall,
     {fname_prefix <> limit.(:fname), create_txi, start_txi, limit.(:local_idx)},
     fn {fname, ct_txi, call_txi, _local_idx} ->
       case fname_checker.(fname) && scope_checker.(call_txi) do
         true -> ct_txi == create_txi || :skip
         false -> false
       end
     end}
  end

  def calls_search_context!([fname: fname_prefix], start_txi, scope_checker, limit) do
    fname_checker = prefix_checker(fname_prefix)

    {Model.FnameIntContractCall, {fname_prefix <> limit.(:fname), start_txi, limit.(:local_idx)},
     fn {fname, call_txi, _local_idx} ->
       fname_checker.(fname) && scope_checker.(call_txi)
     end}
  end

  def calls_search_context!([create_txi: create_txi], start_txi, _scope_checker, limit) do
    {Model.GrpIntContractCall, {create_txi, start_txi, limit.(:local_idx)},
     fn {ct_txi, _start_txi, _log_idx} -> ct_txi == create_txi end}
  end

  def calls_search_context!([], start_txi, scope_checker, limit) do
    {Model.IntContractCall, {start_txi, limit.(:local_idx)},
     fn {call_txi, _} -> scope_checker.(call_txi) end}
  end

  def calls_search_context!(
        [{:create_txi, create_txi}, {:fname, fname_prefix}, {%{} = type_pos, pk}],
        start_txi,
        scope_checker,
        limit
      ) do
    fname_checker = prefix_checker(fname_prefix)

    {Model.GrpIdFnameIntContractCall,
     {create_txi, pk, fname_prefix <> limit.(:fname), limit.(:local_idx), start_txi,
      limit.(:local_idx)},
     fn
       {^create_txi, ^pk, fname, pos, call_txi, local_idx} ->
         case fname_checker.(fname) do
           true ->
             (scope_checker.(call_txi) &&
                pos_match(type_pos, pos, call_txi, local_idx)) ||
               :skip

           false ->
             false
         end

       {_create_txi, _pk, _fname, _pos, _call_txi, _local_idx} ->
         false
     end}
  end

  def calls_search_context!(
        [{:create_txi, create_txi}, {%{} = type_pos, pk}],
        start_txi,
        scope_checker,
        limit
      ) do
    {Model.GrpIdIntContractCall,
     {create_txi, pk, limit.(:local_idx), start_txi, limit.(:local_idx)},
     fn
       {^create_txi, ^pk, pos, call_txi, local_idx} ->
         (scope_checker.(call_txi) &&
            pos_match(type_pos, pos, call_txi, local_idx)) ||
           :skip

       {_create_txi, _pk, _pos, _call_txi, _local_idx} ->
         false
     end}
  end

  def calls_search_context!(
        [{:fname, fname_prefix}, {%{} = type_pos, pk}],
        start_txi,
        scope_checker,
        limit
      ) do
    fname_checker = prefix_checker(fname_prefix)

    {Model.IdFnameIntContractCall,
     {pk, fname_prefix <> limit.(:fname), limit.(:local_idx), start_txi, limit.(:local_idx)},
     fn
       {^pk, fname, pos, call_txi, local_idx} ->
         case fname_checker.(fname) do
           true ->
             (scope_checker.(call_txi) &&
                pos_match(type_pos, pos, call_txi, local_idx)) ||
               :skip

           false ->
             false
         end

       {_pk, _fname, _pos, _call_txi, _local_idx} ->
         false
     end}
  end

  def calls_search_context!([{%{} = type_pos, pk}], start_txi, scope_checker, limit) do
    {Model.IdIntContractCall, {pk, limit.(:local_idx), start_txi, limit.(:local_idx)},
     fn
       {^pk, pos, call_txi, local_idx} ->
         (scope_checker.(call_txi) &&
            pos_match(type_pos, pos, call_txi, local_idx)) ||
           :skip

       {_pk, _pos, _call_txi, _local_idx} ->
         false
     end}
  end

  def calls_search_context!(params),
    do: raise(ErrInput.Query, value: params)

  def pos_match(type_pos, pos, call_txi, local_idx) do
    {tx_type, _tx} =
      Model.IntContractCall
      |> read!({call_txi, local_idx})
      |> Model.int_contract_call(:tx)
      |> :aetx.specialize_type()

    [pos] == Map.get(type_pos, tx_type) || :skip
  end

  ##########

  def tx_id!(enc_tx_hash) do
    ok_nil(:aeser_api_encoder.safe_decode(:tx_hash, enc_tx_hash)) ||
      raise ErrInput.Id, value: enc_tx_hash
  end

  def create_txi!(contract_id) do
    pk = Validate.id!(contract_id)
    Db.Origin.tx_index({:contract, pk}) || -1
  end
end
