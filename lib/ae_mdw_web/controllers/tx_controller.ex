defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdwWeb.Normalize
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

  def txs_or(conn, _req),
    do: Cont.response(conn, &json/2)

  def txs_and(conn, _req),
    do: Cont.response(conn, &json/2)

      {0, 0, 0} ->
        :all

      {0, 0, _} ->
        {:object_checks,
         for(
           {{type, _field, id}, _} <- type_field_ids,
           reduce: MapSet.new(),
           do: (acc -> MapSet.put(acc, {type, id}))
         ), type_field_ids}

  def db_stream(_, :history, scope),
    do: DBS.map(scope, ~t[tx], :json)

  def db_stream(_, {:type, types}, scope),
    do: DBS.map(scope, ~t[type], :json, types)

  def db_stream(_, {:object, types, ids}, scope),
    do: DBS.map(scope, ~t[object], :json, {:id_type, ids, types})

  def db_stream(_, {checker, roots, data}, scope) do
    checker = obj_check_fn(checker)
    DBS.map(scope, ~t[object], {:id, compose(&to_json/1, &checker.(&1, data))}, {:roots, roots})
  end

  def db_stream(:txs, :all, scope),
    do: DBS.map(scope, ~t[tx], :json)

  def db_stream(:txs, {:type, types}, scope),
    do: DBS.map(scope, ~t[type], :json, types)

  def db_stream(:txs, {:object, types, ids}, scope),
    do: DBS.map(scope, ~t[object], :json, {:id_type, ids, types})

  defp obj_check_fn(:object_check_fields_any), do: &object_check_fields_any/2
  defp obj_check_fn(:object_check_fields_all), do: &object_check_fields_all/2
  defp obj_check_fn(:object_check_ids_all), do: &object_check_ids_all/2

  def object_check_fields_any(model_obj, checks) do
    {type, pk, txi} = Model.object(model_obj, :index)
    field = Model.object(model_obj, :role)

    case checks[{type, field, pk}] do
      nil ->
        nil

      pos ->
        model_tx = read_tx!(txi)
        tx_hash = Model.tx(model_tx, :id)
        {_, _, _, tx_rec} = tx_rec_data = tx_rec_data(tx_hash)
        (Validate.id!(elem(tx_rec, pos)) === pk && {model_tx, tx_rec_data}) || nil
    end
  end

  def object_check_fields_all(model_obj, data) do
    {_type, model_tx, tx_rec, tx_rec_data} = tx_data(model_obj)
    tx_field = Model.object(model_obj, :role)

    matches? =
      Enum.reduce_while(data, true, fn
        {^tx_field, {pos, id}}, _ ->
          (Validate.id!(elem(tx_rec, pos)) === id &&
             {:cont, true}) ||
            {:halt, nil}

        {_, _}, _ ->
          {:halt, nil}
      end)

    (matches? && {model_tx, tx_rec_data}) || nil
  end

  def object_check_ids_all(model_obj, {ids_len, ids}) do
    {type, model_tx, tx_rec, tx_rec_data} = tx_data(model_obj)
    tx_ids = AeMdw.Node.tx_ids(type)

    matches? =
      map_size(tx_ids) >= ids_len &&
        Enum.reduce_while(tx_ids, ids_len, fn {_field, pos}, todo ->
          case todo do
            0 ->
              {:halt, true}

            _ ->
              (MapSet.member?(ids, Validate.id!(elem(tx_rec, pos))) &&
                 {:cont, todo - 1}) ||
                {:halt, false}
          end
        end)

    (matches? && {model_tx, tx_rec_data}) || nil
  end

  defp tx_data(model_obj) do
    {type, _pk, txi} = Model.object(model_obj, :index)
    model_tx = read_tx!(txi)
    tx_hash = Model.tx(model_tx, :id)
    {_, _, _, tx_rec} = data = tx_rec_data(tx_hash)
    {type, model_tx, tx_rec, data}
  end

  defp to_json(nil), do: nil

  defp to_json({model_tx, tx_rec_data}),
    do: Model.tx_to_map(model_tx, tx_rec_data)

  def txs_scoped_count_params(conn, combiner),
  ##########

  defp combination(x) when x in [:txs_or, :txs_count_or], do: :or
  defp combination(x) when x in [:txs_and, :txs_count_and], do: :and

  def normalize(:txs, %{} = req),
    do: (map_size(req) == 0 && :history) || Normalize.input_err(:unexpected_parameters)

  def normalize(action, %{} = req),
    do: Normalize.normalize(combination(action), validate(req))

  def validate(req) do
    explicit_tx_types = AeMdwWeb.Validate.tx_types(req)
    {untyped_ids, type_field_ids} = AeMdwWeb.Validate.ids(Map.drop(req, ["type", "type_group"]))
    {explicit_tx_types, untyped_ids, type_field_ids}
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
