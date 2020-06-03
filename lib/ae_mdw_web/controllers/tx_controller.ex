defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Sigil, Db.Util}

  ##########

  def tx(conn, %{"hash" => enc_tx_hash}),
    do: handle_tx_reply(conn, fn -> read_tx_hash(Validate.id!(enc_tx_hash)) end)

  def txi(conn, %{"index" => index}),
    do: handle_tx_reply(conn, fn -> read_tx(Validate.nonneg_int!(index)) end)

  def txs(conn, _req),
    do: Cont.response(conn, &json/2)

  def count(conn, _req),
    do: conn |> json(last_txi())

  def count_id(conn, %{"id" => id}),
    do: handle_input(conn, fn -> conn |> json(id_counts(Validate.id!(id))) end)

  ##########

  def db_stream(_, params, scope),
    do: DBS.map(scope, :json, params)


  def id_counts(<<_::256>> = pk) do
    for tx_type <- AE.tx_types(), reduce: %{} do
      counts ->
        tx_counts =
          for {field, pos} <- AE.tx_ids(tx_type), reduce: %{} do
            tx_counts ->
              case read(Model.IdCount, {tx_type, pos, pk}) do
                [] ->
                  tx_counts

                [rec] ->
                  Map.put(tx_counts, field, Model.id_count(rec, :count))
              end
          end
        map_size(tx_counts) == 0
        && counts
        || Map.put(counts, tx_type, tx_counts)
    end
  end


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
