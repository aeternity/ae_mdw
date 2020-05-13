defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.Normalize
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

  ##########

  def normalize(:txs, %{} = req) do
    explicit_tx_types = Normalize.tx_types(req)
    {untyped_ids, type_field_ids} = Normalize.ids(Map.drop(req, ["type", "type_group"]))

    case {MapSet.size(explicit_tx_types), MapSet.size(untyped_ids), map_size(type_field_ids)} do
      {0, 0, 0} ->
        :all

      {0, 0, _} ->
        {:object_checks,
         for(
           {{type, _field, id}, _} <- type_field_ids,
           reduce: MapSet.new(),
           do: (acc -> MapSet.put(acc, {type, id}))
         ), type_field_ids}

      {_, 0, 0} ->
        {:type, explicit_tx_types}

      {0, _, 0} ->
        {:object, AeMdw.Node.tx_types(), untyped_ids}

      {_, _, 0} ->
        {:object, explicit_tx_types, untyped_ids}

      {_, _, _} ->
        raise AeMdw.Error.Input.Query,
          value: "can not mix explicit types, ids and fields in one query"
    end
  end

  def db_stream(:txs, :all, scope),
    do: DBS.map(scope, ~t[tx], :json)

  def db_stream(:txs, {:type, types}, scope),
    do: DBS.map(scope, ~t[type], :json, types)

  def db_stream(:txs, {:object, types, ids}, scope),
    do: DBS.map(scope, ~t[object], :json, {:id_type, ids, types})

  def db_stream(:txs, {:object_checks, roots, checks}, scope) do
    mapper = fn model_obj ->
      {type, pk, txi} = Model.object(model_obj, :index)
      field = Model.object(model_obj, :role)

      case checks[{type, field, pk}] do
        nil ->
          nil

        pos ->
          model_tx = read_tx!(txi)
          tx_hash = Model.tx(model_tx, :id)
          {_, _, _, tx_rec} = tx_rec_data = tx_rec_data(tx_hash)

          (Validate.id!(elem(tx_rec, pos)) === pk &&
             Model.tx_to_map(model_tx, tx_rec_data)) ||
            nil
      end
    end

    DBS.map(scope, ~t[object], {:id, mapper}, {:roots, roots})
  end

  ##########

  def read_tx_hash(tx_hash) do
    case :aec_db.find_tx_location(tx_hash) do
      :not_found ->
        nil

      mb_hash ->
        {:ok, mb_header} = :aec_chain.get_header(mb_hash)
        height = :aec_headers.height(mb_header)

        {:gen, height}
        |> DBS.map(~t[tx], & &1)
        |> Enum.find(&(Model.tx(&1, :id) == tx_hash))
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
