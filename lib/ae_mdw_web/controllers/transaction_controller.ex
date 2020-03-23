defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Stream.Tx, as: DBSTx
  alias AeMdwWeb.Util
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

  def txs_for_account(conn, %{
        "account" => account,
        "limit" => limit,
        "page" => page,
        "txtype" => type
      }) do
    type = Util.to_tx_type(type)

    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(limit, page, pk, type))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_account(conn, %{"account" => account, "limit" => limit, "page" => page}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(limit, page, pk))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_interval(conn, %{"limit" => limit, "page" => page, "txtype" => type}) do
    type = Util.to_tx_type(type)
    json(conn, %{"transactions" => get_txs(limit, page, type)})
  end

  def txs_for_interval(conn, %{"limit" => limit, "page" => page}) do
    json(conn, %{"transactions" => get_txs(limit, page)})
  end

  defp get_txs(limit, page) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    limit
    |> Util.pagination(page, [], DBSTx.rev_tx())
    |> List.first()
    |> Enum.map(&Model.to_map/1)
  end

  defp get_txs(limit, page, pk, type) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    data =
      pk
      |> DBS.Object.rev_tx()
      |> Stream.map(&Model.to_map/1)
      |> Stream.filter(fn tx -> tx.tx_type == type end)

    limit
    |> Util.pagination(page, [], data)
    |> List.first()
  end

  defp get_txs(limit, page, data) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    limit
    |> Util.pagination(page, [], exec(data))
    |> List.first()
    |> Enum.map(&Model.to_map/1)
  end

  defp exec(data) when is_binary(data), do: DBS.Object.rev_tx(data)
  defp exec(data) when is_atom(data), do: DBS.Type.rev_tx(data)

  defp count(pk) do
    pk
    |> DBS.Object.rev_tx()
    |> Stream.map(&Model.to_map/1)
    |> Enum.count()
  end
end
