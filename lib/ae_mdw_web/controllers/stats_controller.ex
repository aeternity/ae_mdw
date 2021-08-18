defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model

  alias AeMdw.{Db, Validate}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  alias DBS.Resource.Util, as: RU

  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  ##########

  def stream_plug_hook(%Plug.Conn{path_info: [_ | rem]} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    P.handle_assign(
      conn,
      P.parse_scope((rem == [] && ["backward"]) || rem, ["gen"]),
      P.parse_offset(conn.params),
      {:ok, %{}}
    )
  end

  ##########

  def stats(conn, _params),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  def sum_stats(conn, _params),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  ##########

  def db_stream(:stats, params, scope) do
    {{start, _} = range, dir, succ} = progress(scope)
    scope_checker = scope_checker(dir, range)
    advance = RU.advance_signal_fn(succ, fn _ -> true end)

    RU.signalled_resource({{true, start}, advance}, Model.Stat, &Db.Format.to_map(&1, Model.Stat))
  end

  def db_stream(:sum_stats, params, scope) do
    {{start, _} = range, dir, succ} = progress(scope)
    scope_checker = scope_checker(dir, range)
    advance = RU.advance_signal_fn(succ, fn _ -> true end)

    RU.signalled_resource(
      {{true, start}, advance},
      Model.SumStat,
      &Db.Format.to_map(&1, Model.SumStat)
    )
  end

  def progress({:gen, %Range{first: f, last: l}}) do
    cond do
      f <= l -> {{f, l}, :forward, &next/2}
      f > l -> {{f, l}, :backward, &prev/2}
    end
  end

  def scope_checker(:forward, {f, l}), do: fn x -> x >= f && x <= l end
  def scope_checker(:backward, {f, l}), do: fn x -> x >= l && x <= f end
end
