defmodule AeMdwWeb.TransactionController do
  # use AeMdwWeb, :controller

  # alias AeMdw.Db.Model
  # alias AeMdw.Db.Stream, as: DBS
  # alias AeMdwWeb.Util, as: WebUtil
  # alias AeMdwWeb.Continuation, as: Cont
  # require Model

  # import AeMdwWeb.Util, only: [handle_input: 2]
  # import AeMdw.{Sigil, Db.Util, Util}

  # # Hardcoded DB only for testing purpose
  # @txs_for_account_to_account %{
  #   "transactions" => [
  #     %{
  #       "block_height" => 195_065,
  #       "block_hash" => "mh_2fsoWrz5cTRKqPdkRJXcnCn5cC444iyZ9jSUVr6w3tR3ipLH2N",
  #       "hash" => "th_2wZfT7JQRoodrJD5SQkUnHK6ZuwaunDWXYvtaWfE6rNduxDqRb",
  #       "signatures" => [
  #         "sg_ZXp5HWs7UkNLaMf9jorjsXvvpCFVMgEWGiFR3LWp1wRXC1u2meEbMYqrxspYdfc8w39QNk5fbqenEPLwezqbWV2U8R5PS"
  #       ],
  #       "tx" => %{
  #         "amount" => 100_000_000_000_000_000_000,
  #         "fee" => 16_840_000_000_000,
  #         "nonce" => 2,
  #         "payload" => "ba_Xfbg4g==",
  #         "recipient_id" => "ak_2ppoxaXnhSadMM8aw9XBH72cmjse1FET6UkM2zwvxX8fEBbM8U",
  #         "sender_id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
  #         "type" => "SpendTx",
  #         "version" => 1
  #       }
  #     }
  #   ]
  # }

  # def rate(_conn, %{"from" => _from_date, "to" => _to_date}) do
  #   # from = Date.from_iso8601!(from_date)
  #   # to = Date.from_iso8601!(to_date)

  #   _res = [
  #     %{
  #       "amount" => "5980801808761449247022144",
  #       "count" => 36155,
  #       "date" => "2019-11-04"
  #     }
  #   ]

  #   raise "TODO"
  # end

  # def count(conn, %{"address" => id}),
  #   do: handle_input(conn, fn -> json(conn, %{"count" => count_txs(id)}) end)

  # def two_parties(conn, _),
  #   do: Cont.response(conn, &json/2)

  # def account(conn, _),
  #   do: Cont.response(conn, &json/2)

  # def all(conn, _),
  #   do: Cont.response(conn, &json/2)

  # ##########

  # def db_scope(:two_parties, req),
  #   do: WebUtil.gen_scope(req, :asc)
  # def db_scope(_, req),
  #   do: WebUtil.gen_scope(req, :desc)

  # def db_stream(:account, %{"sender" => sender, "receiver" => receiver}, scope),
  #   do: WebUtil.spend_txs(scope, sender, receiver)
  # def db_stream(:account, %{"account" => id, "txtype" => type}, scope),
  #   do: DBS.map(scope, ~t[object], :json, {:id_type, %{id => type}})
  # def db_stream(:account, %{"account" => id}, scope),
  #   do: DBS.map(scope, ~t[object], :json, id)

  # def db_stream(:all, %{"txtype" => type}, scope),
  #   do: DBS.map(scope, ~t[type], :json, type)
  # def db_stream(:all, %{}, scope),
  #   do: DBS.map(scope, ~t[tx], :json)

  # def next_link(:two_parties, scope, page, _conn),
  #   do: "/middleware/"

  # defp count_txs(id),
  #   do: DBS.map(:backward, ~t[object], & &1, id) |> Enum.count()
end
