defmodule Integration.AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Validate

  require Model

  @moduletag :integration

  @big_balance_contract_id1 "ct_BwJcRRa7jTAvkpzc2D16tJzHMGCJurtJMUBtyyfGi2QjPuMVv"
  @big_balance_contract_id2 "ct_uGk1rkSdccPKXLzS259vdrJGTWAY9sfgVYspv6QYomxvWZWBM"

  @default_limit 10

  describe "by_contract" do
    test "gets aex9 tokens sorted by contract", %{conn: conn} do
      contract_id = "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt"

      response =
        conn
        |> get("/aex9/by_contract/#{contract_id}")
        |> json_response(200)

      assert response["data"] ==
               %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG"
               }

      contract_id = "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer"

      response =
        conn
        |> get("/aex9/by_contract/#{contract_id}")
        |> json_response(200)

      assert response["data"] ==
               %{
                 "contract_id" => "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer",
                 "contract_txi" => 9_393_007,
                 "decimals" => 18,
                 "name" => "AAA",
                 "symbol" => "AAA"
               }
    end
  end

  describe "by_name" do
    test "gets aex9 tokens sorted by name", %{conn: conn} do
      response =
        conn
        |> get("/aex9/by_name")
        |> json_response(200)

      assert Enum.any?(response, fn aex9 ->
               aex9 == %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG"
               }
             end)

      assert Enum.any?(response, fn aex9 ->
               aex9 ==
                 %{
                   "contract_id" => "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer",
                   "contract_txi" => 9_393_007,
                   "decimals" => 18,
                   "name" => "AAA",
                   "symbol" => "AAA"
                 }
             end)
    end
  end

  describe "by_symbol" do
    test "gets aex9 tokens sorted by symbol", %{conn: conn} do
      response =
        conn
        |> get("/aex9/by_symbol")
        |> json_response(200)

      assert Enum.any?(response, fn aex9 ->
               aex9 ==
                 %{
                   "contract_id" => "ct_2TZsPKT5wyahqFrzp8YX7DfXQapQ4Qk65yn3sHbifU9Db9hoav",
                   "contract_txi" => 12_361_891,
                   "decimals" => 18,
                   "name" => "911058",
                   "symbol" => "SPH"
                 }
             end)

      assert Enum.any?(response, fn aex9 ->
               aex9 == %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG"
               }
             end)
    end
  end

  describe "balance_range" do
    test "gets account balance on a contract for range of generations", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      account_id = "ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"
      first = 489_501
      last = 489_510

      path =
        Routes.aex9_path(
          conn,
          :balance_range,
          "#{first}-#{last}",
          contract_id,
          account_id
        )

      response = conn |> get(path) |> json_response(200)
      assert response["contract_id"] == contract_id
      assert response["account_id"] == account_id
      assert is_list(response["range"])

      response["range"]
      |> Enum.zip(first..last)
      |> Enum.each(fn {height_map, height} ->
        assert %{
                 "amount" => amount,
                 "block_hash" => hash,
                 "height" => ^height
               } = height_map

        assert (height < 489_509 && amount == 9_975_045) || amount == 9_975_135
        assert String.starts_with?(hash, "kh_") and match?({:ok, _hash_bin}, Validate.id(hash))
      end)
    end
  end

  describe "balances_range" do
    test "gets balances on a contract for range of generations", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      first = 489_501
      last = 489_510

      path =
        Routes.aex9_path(
          conn,
          :balances_range,
          "#{first}-#{last}",
          "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
        )

      response = conn |> get(path) |> json_response(200)
      assert response["contract_id"] == contract_id
      assert is_list(response["range"])

      response["range"]
      |> Enum.zip(first..last)
      |> Enum.each(fn {height_map, height} ->
        assert %{
                 "amounts" => amounts,
                 "block_hash" => hash,
                 "height" => ^height
               } = height_map

        assert (height < 489_509 &&
                  amounts["ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"] == 9_975_045) ||
                 amounts["ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"] == 9_975_135

        assert String.starts_with?(hash, "kh_") and match?({:ok, _hash_bin}, Validate.id(hash))
      end)
    end
  end

  describe "balance_for_hash" do
    test "gets balance for hash", %{conn: conn} do
      mb_hash = "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      account_id = "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      conn = get(conn, "/aex9/balance/hash/#{mb_hash}/#{contract_id}/#{account_id}")

      assert %{
               "account_id" => "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
               "amount" => 49_999_999_999_906_850_000_000_000,
               "block_hash" => ^mb_hash,
               "contract_id" => ^contract_id,
               "height" => 350_622
             } = json_response(conn, 200)
    end
  end

  describe "balances_for_hash" do
    test "gets balances for hash and contract", %{conn: conn} do
      mb_hash = "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/aex9/balances/hash/#{mb_hash}/#{contract_id}")

      assert %{
               "amounts" => %{
                 "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6" => 4_050_000_000_000,
                 "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK" => 8_100_000_000_000,
                 "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4" => 81_000_000_000_000,
                 "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" =>
                   49_999_999_999_906_850_000_000_000
               },
               "block_hash" => ^mb_hash,
               "contract_id" => ^contract_id,
               "height" => 350_622
             } = json_response(conn, 200)
    end

    test "gets balances for hash and account", %{conn: conn} do
      mb_height = 578_684
      mb_hash = "mh_2eSwMRK7KXtPZqkciBWU2o764yZ8QCttWUSxvh2aRWwDE15oVm"
      account_id = "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx"
      conn = get(conn, "/aex9/balances/hash/#{mb_hash}/account/#{account_id}")

      response_list = json_response(conn, 200)

      assert Enum.any?(response_list, fn balance ->
               balance == %{
                 "amount" => 100_000_000_000_000_000_000_000_000,
                 "block_hash" => "mh_26Rfn9fBcaKc2YcpDKD11Aai8jMSdbuqt22DFdqisqLdS8sg6n",
                 "contract_id" => "ct_wi5be3qiXGWe1DbMTGVyBqkQiNz1K7kch7go9zJDeiHbbAMZ1",
                 "height" => 466_128,
                 "token_name" => "AVT",
                 "token_symbol" => "ae vegas token",
                 "tx_hash" => "th_2F529Nr3LQBjSwiiWSs2XHW2cNrKi4f9KedH34CBSBPSzbEcNP",
                 "tx_index" => 24_439_019,
                 "tx_type" => "contract_call_tx"
               }
             end)

      assert Enum.all?(response_list, fn %{"height" => height, "tx_type" => "contract_call_tx"} ->
               height < mb_height
             end)

      assert length(response_list) == 31
    end
  end

  describe "balances" do
    test "gets all accounts balances for a contract", %{conn: conn} do
      contract_id = @big_balance_contract_id1
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts_map,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      Enum.each(amounts_map, fn {account, balance} ->
        assert String.starts_with?(account, "ak_")
        assert is_integer(balance) and balance >= 0
      end)
    end

    test "gets accounts balances for a contract with less than 100 amounts", %{conn: conn} do
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      assert is_map(amounts) and map_size(amounts) > 0 and map_size(amounts) < 100
    end

    test "returns the empty amounts for aex9 contract without balance", %{conn: conn} do
      contract_id = "ct_U7whpYJo4xXoXjEpw39mWEPKgKM2kgSZk9em5FLK8Xq2FrRWE"
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      assert is_map(amounts) and map_size(amounts) == 0
    end
  end

  describe "balance" do
    test "gets an account balances for multiple contracts", %{conn: conn} do
      account_id = "ak_WzcSck8B9ZPgHsy5XeqBbtUV4YbTuGyyJUzhSMvSK2JY1nzqJ"
      conn = get(conn, "/aex9/balances/account/#{account_id}")

      balances_response = json_response(conn, 200)

      assert Enum.any?(balances_response, fn %{"contract_id" => contract_id} ->
               contract_id == @big_balance_contract_id2
             end)

      Enum.each(balances_response, fn %{
                                        "contract_id" => contract_id,
                                        "token_name" => token_name,
                                        "token_symbol" => token_symbol
                                      } ->
        {:contract_pubkey, contract_pk} = :aeser_api_encoder.decode(contract_id)
        create_txi = Origin.tx_index!({:contract, contract_pk})

        {^create_txi, name, symbol, _decimals} =
          Util.next(Model.RevAex9Contract, {create_txi, nil, nil, nil})

        assert token_name == name
        assert token_symbol == symbol
      end)
    end
  end

  describe "transfers from" do
    test "a sender paginated backwards with limit = 100", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      limit = 100

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated backwards with default limit", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated forward with limit = 100", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      limit = 100

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", limit: limit, direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated forward with default limit", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers to" do
    test "a recipient paginated backwards with limit = 100", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 50

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated backwards with default limit", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated forward with limit = 100", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 50

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", limit: limit, direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated forward with default limit", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers from-to" do
    test "paginated backwards with limit = 100", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 30

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated backwards with default limit", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated forward with limit = 100", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 30

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}",
          limit: limit,
          direction: "forward"
        )
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated forward with default limit", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers_from_v1" do
    test "from a sender with many transfers", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      conn = get(conn, "/aex9/transfers/from/#{account_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end

  describe "transfers_to_v1" do
    test "to a recipient with many transfers", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      conn = get(conn, "/aex9/transfers/to/#{account_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"recipient" => recipient_id} ->
               recipient_id == account_id
             end)

      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end

  describe "transfers_from_to_v1" do
    test "from a pair with many transfers", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      conn = get(conn, "/aex9/transfers/from-to/#{from_id}/#{to_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end
end
