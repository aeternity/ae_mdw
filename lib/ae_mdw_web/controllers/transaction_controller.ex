defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Util, as: WebUtil
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdw.{Sigil, Util}

  # Hardcoded DB only for testing purpose
  @txs_for_account_to_account %{
    "transactions" => [
      %{
        "block_height" => 195_065,
        "block_hash" => "mh_2fsoWrz5cTRKqPdkRJXcnCn5cC444iyZ9jSUVr6w3tR3ipLH2N",
        "hash" => "th_2wZfT7JQRoodrJD5SQkUnHK6ZuwaunDWXYvtaWfE6rNduxDqRb",
        "signatures" => [
          "sg_ZXp5HWs7UkNLaMf9jorjsXvvpCFVMgEWGiFR3LWp1wRXC1u2meEbMYqrxspYdfc8w39QNk5fbqenEPLwezqbWV2U8R5PS"
        ],
        "tx" => %{
          "amount" => 100_000_000_000_000_000_000,
          "fee" => 16_840_000_000_000,
          "nonce" => 2,
          "payload" => "ba_Xfbg4g==",
          "recipient_id" => "ak_2ppoxaXnhSadMM8aw9XBH72cmjse1FET6UkM2zwvxX8fEBbM8U",
          "sender_id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
          "type" => "SpendTx",
          "version" => 1
        }
      }
    ]
  }

  # @tx_rate [
  #   %{
  #     "amount" => "5980801808761449247022144",
  #     "count" => 36155,
  #     "date" => "2019-11-04"
  #   }
  # ]

  def rate(_conn, %{"from" => _from_date, "to" => _to_date}) do
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

  def count(conn, %{"address" => id}),
    do:
      handle_input(
        conn,
        fn ->
          count = DBS.map(:backward, ~t[object], :json, id) |> Enum.count()
          json(conn, %{"count" => count})
        end
      )

  def account(conn, req),
    do: handle_input(conn, fn -> json(conn, response(conn)) end)

  def interval(conn, %{} = req),
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
