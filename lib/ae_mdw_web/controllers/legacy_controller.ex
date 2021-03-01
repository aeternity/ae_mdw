defmodule AeMdwWeb.LegacyController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont

  import AeMdwWeb.Util

  ##########

  def account_txs(conn, %{"account" => account} = params) do
    {:ok, {limit, page}} = AeMdwWeb.DataStreamPlug.parse_offset(params)
    offset = (page - 1) * limit
    handle_input(conn,
      fn ->
        account_pk = Validate.id!(account)
        cont_key = {__MODULE__, :account_txs, account_pk, client_id(conn), offset}
        json(conn,
          case Cont.response_data(cont_key, limit) do
            {:ok, raw_data, _} -> Enum.map(raw_data, &format_tx/1)
            {:error, :dos} -> []
          end)
      end
    )
  end

  ##########

  def db_stream(:account_txs, account_pk, _),
    do: DBS.map(:backward, :json, account: account_pk, type: :spend)

  def client_id(conn),
    do: {conn.remote_ip, List.keyfind(conn.req_headers, "user-agent", 0)}

  def format_tx(%{"micro_time" => time} = tx) do
    tx
    |> Map.drop(["micro_index", "micro_time", "tx_index"])
    |> Map.put("time", time)
  end

end
