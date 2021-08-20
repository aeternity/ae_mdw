defmodule AeMdwWeb.TransferController do
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

  def stream_plug_hook(%Plug.Conn{path_info: ["transfers" | rem]} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    P.handle_assign(
      conn,
      P.parse_scope((rem == [] && ["backward"]) || rem, ["gen"]),
      P.parse_offset(conn.params),
      {:ok, %{}}
    )
  end

  ##########

  def transfers(conn, _params),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  ##########

  def db_stream(:transfers, params, scope) do
    alias DBS.Resource.Util, as: RU

    {{start, _} = range, dir, succ} = progress(scope)
    scope_checker = scope_checker(dir, range)

    {tab, init_key, key_tester} =
      transfers_search_context!(params, start, scope_checker, limit(dir))

    advance = RU.advance_signal_fn(succ, key_tester)

    RU.signalled_resource({{:skip, init_key}, advance}, tab, fn m_obj ->
      index = elem(m_obj, 1)
      Db.Format.to_map(normalize_key(index, tab), Model.IntTransferTx)
    end)
  end

  def normalize_key({location, kind, target_pk, ref_txi}, Model.IntTransferTx),
    do: {location, kind, target_pk, ref_txi}

  def normalize_key({kind, location, target_pk, ref_txi}, Model.KindIntTransferTx),
    do: {location, kind, target_pk, ref_txi}

  def normalize_key({target_pk, location, kind, ref_txi}, Model.TargetIntTransferTx),
    do: {location, kind, target_pk, ref_txi}

  def convert({"account", [account_id]}),
    do: [account_pk: Validate.id!(account_id, [:account_pubkey])]

  def convert({"kind", [kind_prefix]}), do: [kind_prefix: kind_prefix]

  def limit(:forward), do: &min/1
  def limit(:backward), do: &max/1

  def min(:kind_prefix), do: ""
  def min(:target_pk), do: <<>>
  def min(:ref_txi), do: -1

  def max(:kind_prefix), do: AeMdw.Node.max_blob()
  def max(:target_pk), do: <<max_256bit_int()::256>>
  def max(:ref_txi), do: max_256bit_int()

  def progress({:gen, %Range{first: f, last: l}}) do
    cond do
      f <= l -> {{{f, -100}, {l, max_256bit_int()}}, :forward, &next/2}
      f > l -> {{{f, max_256bit_int()}, {l, -100}}, :backward, &prev/2}
    end
  end

  def scope_checker(:forward, {f, l}), do: fn x -> x >= f && x <= l end
  def scope_checker(:backward, {f, l}), do: fn x -> x >= l && x <= f end

  ##########

  def transfers_search_context!(%{} = params, start, scope_checker, limit_fn) do
    params
    |> Enum.to_list()
    |> Enum.sort()
    |> Enum.flat_map(&convert/1)
    |> transfers_search_context!(start, scope_checker, limit_fn)
  end

  def transfers_search_context!(
        [account_pk: target_pk, kind_prefix: kind_prefix],
        start,
        scope_checker,
        limit
      ) do
    kind_checker = prefix_checker(kind_prefix)

    {Model.TargetIntTransferTx,
     {target_pk, start, kind_prefix <> limit.(:kind_prefix), limit.(:ref_txi)},
     fn {pk, loc, kind, _} -> pk == target_pk && scope_checker.(loc) && kind_checker.(kind) end}
  end

  def transfers_search_context!([kind_prefix: kind_prefix], start, scope_checker, limit) do
    kind_checker = prefix_checker(kind_prefix)

    {Model.KindIntTransferTx,
     {kind_prefix <> limit.(:kind_prefix), start, limit.(:target_pk), limit.(:ref_txi)},
     fn {kind, loc, _, _} -> kind_checker.(kind) && scope_checker.(loc) end}
  end

  def transfers_search_context!([account_pk: target_pk], start, scope_checker, limit) do
    {Model.TargetIntTransferTx, {target_pk, start, limit.(:kind_prefix), limit.(:ref_txi)},
     fn {pk, loc, _, _} -> pk == target_pk && scope_checker.(loc) end}
  end

  def transfers_search_context!([], start, scope_checker, limit) do
    {Model.IntTransferTx, {start, limit.(:kind_prefix), limit.(:target_pk), limit.(:ref_txi)},
     fn {loc, _, _, _} -> scope_checker.(loc) end}
  end

  def transfers_search_context!(params, _start, _scope_checker, _limit),
    do: raise(ErrInput.Query, value: params)
end
