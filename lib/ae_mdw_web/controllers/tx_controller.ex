defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.SwaggerParameters
  require Model

  import AeMdwWeb.Util
  import AeMdw.Db.Util

  ##########

  def tx(conn, %{"hash" => enc_tx_hash}),
    do: handle_tx_reply(conn, fn -> read_tx_hash(Validate.id!(enc_tx_hash)) end)

  def txi(conn, %{"index" => index}),
    do: handle_tx_reply(conn, fn -> read_tx(Validate.nonneg_int!(index)) end)

  def txs_direction(conn, req),
    do: txs(conn, req)

  def txs_range(conn, req),
    do: txs(conn, req)

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

        (map_size(tx_counts) == 0 &&
           counts) ||
          Map.put(counts, tx_type, tx_counts)
    end
  end

  def read_tx_hash(tx_hash) do
    with <<_::256>> = mb_hash <- :aec_db.find_tx_location(tx_hash),
         {:ok, mb_header} <- :aec_chain.get_header(mb_hash),
         height <- :aec_headers.height(mb_header) do
      DBS.map({:gen, height}, & &1)
      |> Enum.find(&(Model.tx(&1, :id) == tx_hash))
    else
      _ -> nil
    end
  end

  defp txs(conn, _req),
    do: Cont.response(conn, &json/2)

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

  ##########

  swagger_path :tx do
    get("/tx/{hash}")
    description("Get a transaction by a given hash.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_by_hash")
    tag("Middleware")

    parameters do
      hash(:path, :string, "The transaction hash.",
        required: true,
        example: "th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq"
      )
    end

    response(200, "Returns the transaction.", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :txi do
    get("/txi/{index}")
    description("Get a transaction by a given index.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_by_index")
    tag("Middleware")

    parameters do
      index(:path, :integer, "The transaction index.", required: true, example: 10_000_000)
    end

    response(200, "Returns the transaction.", %{})
    response(404, "Not found.", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :txs_direction do
    get("/txs/{direction}")

    description(
      "Get a transactions from beginning or end of the chain. More [info](https://github.com/aeternity/ae_mdw#transaction-querying)."
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_txs_by_direction")
    tag("Middleware")
    SwaggerParameters.common_params()

    parameters do
      direction(
        :path,
        :string,
        "The direction - **forward** is from genesis to the end, **backward** is from end to the beginning.",
        enum: [:forward, :backward],
        required: true
      )

      sender_id(:query, :string, "The sender.",
        required: false,
        exaple: "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      )

      recipient_id(:query, :string, "The recipient.",
        required: false,
        exaple: "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"
      )
    end

    response(200, "Returns result regarding the according criteria.", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :txs_range do
    get("/txs/{scope_type}/{range}")
    description("Get a transactions bounded by scope/range.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_txs_by_scope_type_range")
    tag("Middleware")
    SwaggerParameters.common_params()

    parameters do
      scope_type(:path, :string, "The scope type.", enum: [:gen, :txi], required: true)
      range(:path, :string, "The range.", required: true, example: "0-265354")
    end

    response(200, "Returns result regarding the according criteria.", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :count do
    get("/txs/count")
    description("Get count of transactions at the current height.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_current_tx_count")
    tag("Middleware")
    response(200, "Returns count of all transactions at the current height.", %{})
  end

  swagger_path :count_id do
    get("/txs/count/{id}")
    description("Get transactions count and its type for given aeternity ID.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_count_by_id")
    tag("Middleware")

    parameters do
      id(:path, :string, "The ID.",
        required: true,
        example: "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"
      )
    end

    response(200, "Returns transactions count and its type for given aeternity ID.", %{})
    response(400, "Bad request.", %{})
  end
end
