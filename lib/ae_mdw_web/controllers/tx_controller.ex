defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdwWeb.Query
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Sigil, Db.Util, Util}

  ##########

  def tx(conn, %{"hash" => enc_tx_hash}),
    do: handle_tx_reply(conn, fn -> read_tx_hash(Validate.id!(enc_tx_hash)) end)

  def txi(conn, %{"index" => index}),
    do: handle_tx_reply(conn, fn -> read_tx(Validate.nonneg_int!(index)) end)

  def txs(conn, _req),
    do: Cont.response(conn, &json/2)

  # def txs_count(conn, req),
  #   do:
  #     handle_input(conn, fn ->
  #       (map_size(req) == 0 &&
  #          json(conn, %{"count" => last_txi() + 1})) ||
  #         Normalize.input_err(:unexpected_parameters)
  #     end)

  # def txs_scoped_count(conn, req),
  #   do:
  #     handle_input(conn, fn ->
  #       map_size(Map.drop(req, ["range", "scope_type"])) == 0 ||
  #         Normalize.input_err(:unexpected_parameters)

  #       stream = db_stream_raw(:txs_scoped_count, :history, conn.assigns.scope)
  #       json(conn, %{"count" => Enum.count(stream)})
  #     end)

  # def txs_scoped_count_or(conn, _req),
  #   do: txs_scoped_count_params(conn, :txs_count_or)

  # def txs_scoped_count_and(conn, _req),
  #   do: txs_scoped_count_params(conn, :txs_count_and)

  ##########

  def db_stream(_, :history, scope),
    do: DBS.map(scope, ~t[tx], :json)

  def db_stream(_, {ids, types}, scope) when map_size(ids) == 0,
    do: DBS.map(scope, ~t[type], :json, types)

  def db_stream(_, {ids, types}, scope) when map_size(ids) > 0 do
    case Query.Planner.plan({ids, types}) do
      nil ->
        Stream.map([], & &1)

      {roots, checks} ->
        record_fn =
          (map_size(checks) == 0 &&
             :json) ||
            {:id, compose(&to_json/1, &checker(&1, checks))}

        DBS.map(scope, ~t[field], record_fn, {:roots, MapSet.new(roots)})
    end
  end

  # def db_stream(_, {:type, types}, scope),
  #   do: DBS.map(scope, ~t[type], :json, types)

  # def db_stream(_, {checker, roots, data}, scope) do
  #   checker = obj_check_fn(checker)
  #   DBS.map(scope, ~t[object], {:id, compose(&to_json/1, &checker.(&1, data))}, {:roots, roots})
  # end

  # def db_stream_raw(_, :history, scope),
  #   do: DBS.map(scope, ~t[tx], &id/1)

  # def db_stream_raw(_, {:type, types}, scope),
  #   do: DBS.map(scope, ~t[type], &id/1, types)

  ##########

  def checker(model_field, all_checks) do
    {type, model_tx, tx_rec, data} = tx_data(model_field)
    txi = Model.tx(model_tx, :index)
    tx_hash = Model.tx(model_tx, :id)
    type_checks = Map.get(all_checks, type, [])

    valid? =
      Enum.reduce_while(type_checks, nil, fn
        {pk_pos, pk_pos_checks}, nil ->
          case check_field(pk_pos, tx_rec, type, txi, tx_hash) do
            false ->
              {:cont, nil}

            true ->
              check = &check_field(&1, tx_rec, type, txi, tx_hash)
              {:halt, Enum.all?(pk_pos_checks, check) || nil}
          end
      end)

    valid? && {model_tx, data}
  end

  def check_field({pk, nil}, tx_rec, type, txi, hash),
    do: read(Model.RevOrigin, {txi, type, hash}) != []

  def check_field({pk, pos}, tx_rec, _type, _txi, _hash),
    do: Validate.id!(elem(tx_rec, pos)) === pk

  def tx_data(model_field) do
    {type, _pos, _pk, txi} = Model.field(model_field, :index)
    model_tx = read_tx!(txi)
    tx_hash = Model.tx(model_tx, :id)
    {_, _, _, tx_rec} = data = tx_rec_data(tx_hash)
    {type, model_tx, tx_rec, data}
  end

  defp to_json(nil), do: nil

  defp to_json({model_tx, tx_rec_data}),
    do: Model.tx_to_map(model_tx, tx_rec_data)

  # def txs_scoped_count_params(conn, combiner),
  #   do:
  #     handle_input(conn, fn ->
  #       params = query_groups(conn.query_string) |> Map.drop(["limit", "page"])

  #       count =
  #         case normalize(combiner, Map.drop(params, ["range", "scope_type"])) do
  #           :history ->
  #             last_txi() + 1

  #           normalized ->
  #             Enum.count(db_stream_raw(combiner, normalized, conn.assigns.scope))
  #         end

  #       json(conn, %{"count" => count})
  #     end)

  ##########

  def normalize(:txs, %{} = query_groups),
    do: (map_size(query_groups) == 0 && :history) || Query.Parser.parse(query_groups)

  ##########

  def read_tx_hash(tx_hash) do
    with <<_::256>> = mb_hash <- :aec_db.find_tx_location(tx_hash),
         {:ok, mb_header} <- :aec_chain.get_header(mb_hash),
         height <- :aec_headers.height(mb_header) do
      {:gen, height}
      |> DBS.map(~t[tx], & &1)
      |> Enum.find(&(Model.tx(&1, :id) == tx_hash))
    else
      _ -> nil
    end
  end

  defp handle_tx_reply(conn, source_fn),
    do: handle_input(conn, fn -> tx_reply(conn, source_fn.()) end)

  defp tx_reply(conn, []),
    do: tx_reply(conn, nil)

  defp tx_reply(conn, nil),
    do: conn |> send_error(:not_found, "no such transaction")

  defp tx_reply(conn, [model_tx]),
    do: tx_reply(conn, model_tx)

  defp tx_reply(conn, model_tx) when is_tuple(model_tx) and elem(model_tx, 0) == :tx,
    do: conn |> json(Model.tx_to_map(model_tx))
end
