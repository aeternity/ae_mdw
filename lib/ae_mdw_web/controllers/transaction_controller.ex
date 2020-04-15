defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Util, as: WebUtil
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdw.Sigil

  swagger_path :tx_rate_by_date_range do
    get("/transactions/rate/{from}/{to}")
    description("Get transaction amount and count for the date interval")
    produces(["application/json"])
    deprecated(false)
    operation_id("tx_rate_by_date_range")

    parameters do
      from(:path, :string, "Start Date(yyyymmdd)", required: true)
      to(:path, :string, "End Date(yyyymmdd)", required: true)
    end

    response(200, "", %{})
  end

  def tx_rate_by_date_range(_conn, %{"from" => _from_date, "to" => _to_date}) do
    # from = Date.from_iso8601!(from_date)
    # to = Date.from_iso8601!(to_date)

    _res = [
      %{
        "amount" => "5980801808761449247022144",
        "count" => 36155,
        "date" => "2019-11-04"
      }
    ]

    raise "TODO"
  end

  swagger_path :tx_count_by_address do
    get("transactions/account/{address}/count")
    description("Get the count of transactions for a given account address")
    produces(["application/json"])
    deprecated(false)
    operation_id("tx_count_by_address")

    parameters do
      address(:path, :string, "Account address", required: true)
      txtype(:query, :string, "Transaction Type", required: false)
    end

    response(200, "", %{})
  end

  def tx_count_by_address(conn, %{"address" => id}),
    do:
      handle_input(
        conn,
        fn ->
          count = DBS.map(:backward, ~t[object], :json, id) |> Enum.count()
          json(conn, %{"count" => count})
        end
      )

  swagger_path :tx_by_account do
    get("/transactions/account/{address}")
    description("Get list of transactions for a given account")
    produces(["application/json"])
    deprecated(false)
    operation_id("tx_by_account")

    parameters do
      account(:path, :string, "Account address", required: true)
      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
    end

    response(200, "", %{})
  end

  def tx_by_account(conn, _req),
    do: handle_input(conn, fn -> json(conn, response(conn)) end)

  swagger_path :tx_between_address do
    get("/transactions/account/{sender}/to/{receiver}")
    description("Get a list of transactions between two accounts")
    produces(["application/json"])
    deprecated(false)
    operation_id("tx_between_address")

    parameters do
      sender(:path, :string, "Sender account address", required: true)
      receiver(:path, :string, "Receiver account address", required: true)
    end

    response(200, "", %{})
  end

  def tx_between_address(conn, _req),
    do: handle_input(conn, fn -> json(conn, response(conn)) end)

  swagger_path :tx_by_generation_range do
    get("/transactions/interval/{from}/{to}")
    description("Get transactions between an interval of generations")
    produces(["application/json"])
    deprecated(false)
    operation_id("tx_by_generation_range")

    parameters do
      from(:path, :integer, "Start Generation/Key-block height", required: true)
      to(:path, :integer, "End Generation/Key-block height", required: true)
      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
      txtype(:query, :string, "Transaction Type", required: false)
    end

    response(200, "", %{})
  end

  def tx_by_generation_range(conn, %{} = _req),
    do: handle_input(conn, fn -> json(conn, %{"transactions" => response(conn)}) end)

  ##########

  def response(conn),
    do: Cont.response(conn, &db_stream/1)

  def db_stream(req) do
    scope = WebUtil.scope(req)
    scope = (scope && {:gen, scope}) || :backward

    case req do
      %{"sender" => sender, "receiver" => receiver} ->
        WebUtil.spend_txs(sender, receiver)

      %{"account" => id, "txtype" => type} ->
        DBS.map(scope, ~t[object], :json, {:id_type, %{id => type}})

      %{"account" => id} ->
        DBS.map(scope, ~t[object], :json, id)

      %{"txtype" => type} ->
        DBS.map(scope, ~t[type], :json, type)

      %{} ->
        DBS.map(scope, ~t[tx], :json)
    end
  end

  def handle_input(conn, f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        conn
        |> put_status(:bad_request)
        |> json(%{"reason" => err.msg})
    end
  end
end
