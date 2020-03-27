defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Stream.Tx, as: DBSTx
  alias AeMdwWeb.{ContinuationData, EtsManager, Util}

  require Model

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

  @tx_rate [
    %{
      "amount" => "5980801808761449247022144",
      "count" => 36155,
      "date" => "2019-11-04"
    }
  ]

  def txs_for_account_to_account(conn, _params) do
    json(conn, @txs_for_account_to_account)
  end

  def tx_rate(conn, _params) do
    json(conn, @tx_rate)
  end

  def txs_count_for_account(conn, %{"address" => account}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, %{"count" => count(pk)})

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_account(
        conn,
        %{
          "account" => account,
          "limit" => limit,
          "page" => page,
          "txtype" => type
        }
      ) do
    type = Util.to_tx_type(type)
    endpoint = conn.path_info ++ [type]

    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(conn, endpoint, [pk, type], limit, page))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_account(conn, %{"account" => account, "limit" => limit, "page" => page}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(conn, conn.path_info, pk, limit, page))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_account(conn, %{"account" => account}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        txs = pk |> DBS.Object.rev_tx() |> Enum.map(&Model.to_map/1)
        json(conn, txs)

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_interval(conn, %{"limit" => limit, "page" => page, "txtype" => type}) do
    type = Util.to_tx_type(type)
    endpoint = conn.path_info ++ [type]

    json(conn, %{"transactions" => get_txs(conn, endpoint, type, limit, page)})
  end

  def txs_for_interval(conn, %{"limit" => limit, "page" => page}) do
    json(conn, %{"transactions" => get_txs(conn, conn.path_info, :all_txs, limit, page)})
  end

  defp get_txs(conn, endpoint, data, limit, page) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)
    key = {conn.assigns.peer_ip, conn.assigns.browser_info}

    with true <- EtsManager.is_member?(key),
         %ContinuationData{
           endpoint: endpoint_,
           continuation: continuation,
           page: page_,
           limit: limit_,
           timestamp: timestamp
         } <- EtsManager.get(key),
         true <- endpoint == endpoint_,
         true <- page == page_ + 1,
         true <- limit == limit_,
         {txs_list, new_continuation} <- Util.pagination(continuation, limit) do
      EtsManager.put(key, endpoint, new_continuation, page, limit)
      check_txs_list(txs_list)
    else
      false ->
        {txs_list, new_continuation} = Util.pagination(limit, page, exec(data))
        EtsManager.put(key, endpoint, new_continuation, page, limit)
        check_txs_list(txs_list)
    end
  end

  defp exec(:all_txs), do: DBSTx.rev_tx()
  defp exec(data) when is_binary(data), do: DBS.Object.rev_tx(data)
  defp exec(data) when is_atom(data), do: DBS.Type.rev_tx(data)

  defp exec([pk | t] = data) when is_list(data) do
    [type] = t

    pk
    |> DBS.Object.rev_tx()
    |> Stream.map(&Model.to_map/1)
    |> Stream.filter(fn tx -> tx.tx_type == type end)
  end

  defp check_txs_list(txs_list) do
    if Enum.all?(txs_list, &is_map/1) do
      txs_list
    else
      txs_list |> Enum.map(&Model.to_map/1)
    end
  end

  defp count(pk) do
    pk
    |> DBS.Object.rev_tx()
    |> Stream.map(&Model.to_map/1)
    |> Enum.count()
  end
end
