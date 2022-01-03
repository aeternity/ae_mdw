defmodule Integration.AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Validate

  require Model

  @moduletag :integration

  @big_balance_contract_id "ct_2M4mVQCDVxu6mvUrEue1xMafLsoA1bgsfC3uT95F3r1xysaCvE"

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
    test "gets balances for hash", %{conn: conn} do
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
  end

  describe "balances" do
    test "gets all accounts balances for a contract", %{conn: conn} do
      contract_id = @big_balance_contract_id
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
  end

  describe "balance" do
    test "gets an account balances for multiple contracts", %{conn: conn} do
      account_id = "ak_WzcSck8B9ZPgHsy5XeqBbtUV4YbTuGyyJUzhSMvSK2JY1nzqJ"
      conn = get(conn, "/aex9/balances/account/#{account_id}")

      balances_response = json_response(conn, 200)

      assert Enum.any?(balances_response, fn %{"contract_id" => contract_id} ->
               contract_id == @big_balance_contract_id
             end)

      assert Enum.each(balances_response, fn %{
                                               "contract_id" => contract_id,
                                               "token_name" => token_name,
                                               "token_symbol" => token_symbol
                                             } ->
               create_txi = Origin.tx_index({:contract, contract_id})

               {^create_txi, name, symbol, _decimals} =
                 Util.next(Model.RevAex9Contract, {create_txi, nil, nil, nil})

               assert token_name == name
               assert token_symbol == symbol
             end)
    end
  end
end
