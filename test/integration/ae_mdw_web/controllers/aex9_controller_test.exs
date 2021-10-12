defmodule Integration.AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase, async: false

  @moduletag :integration

  @big_balance_contract_id "ct_2M4mVQCDVxu6mvUrEue1xMafLsoA1bgsfC3uT95F3r1xysaCvE"

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

      assert Enum.find(balances_response, fn %{"contract_id" => contract_id} ->
               contract_id == @big_balance_contract_id
             end)
    end
  end
end
