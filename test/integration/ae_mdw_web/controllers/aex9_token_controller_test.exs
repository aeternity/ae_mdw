defmodule Integration.AeMdwWeb.Aex9TokenControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  require Model

  @moduletag :integration

  @default_limit 10
  @aex9_token_id "ct_2tVVddgw4UGRQ7wGYTAPXWZnMowo9x48iDpvx8idXzKLgFiHW1"
  @aex9_token_account_id "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF"

  describe "aex9_tokens" do
    test "it gets aex9 tokens backwards by name", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9") |> json_response(200)

      aex9_names = aex9_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_names =
        next_aex9_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_names = Enum.sort(next_aex9_names)
      assert Enum.at(aex9_names, @default_limit - 1) >= Enum.at(next_aex9_names, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "it gets aex9 tokens forwards by name", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9", direction: "forward") |> json_response(200)

      aex9_names = Enum.map(aex9_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_names = Enum.map(next_aex9_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_names = Enum.sort(next_aex9_names)
      assert Enum.at(aex9_names, @default_limit - 1) <= Enum.at(next_aex9_names, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "it gets aex9 tokens filtered by name prefix", %{conn: conn} do
      prefix = "AAA"

      assert %{"data" => aex9_tokens} =
               conn |> get("/v2/aex9", prefix: prefix) |> json_response(200)

      assert length(aex9_tokens) > 0
      assert Enum.all?(aex9_tokens, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
    end

    test "it gets aex9 tokens backwards by symbol", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9", by: "symbol") |> json_response(200)

      aex9_symbols =
        aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_symbols =
        next_aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_symbols = Enum.sort(next_aex9_symbols)
      assert Enum.at(aex9_symbols, @default_limit - 1) >= Enum.at(next_aex9_symbols, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "it gets aex9 tokens forwards by symbol", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9", direction: "forward", by: "symbol") |> json_response(200)

      aex9_symbols = Enum.map(aex9_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_symbols = Enum.map(next_aex9_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_symbols = Enum.sort(next_aex9_symbols)
      assert Enum.at(aex9_symbols, @default_limit - 1) <= Enum.at(next_aex9_symbols, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "it gets aex9 tokens filtered by symbol prefix", %{conn: conn} do
      prefix = "AAA"

      assert %{"data" => aex9_tokens} =
               conn |> get("/v2/aex9", by: "symbol", prefix: prefix) |> json_response(200)

      assert length(aex9_tokens) > 0

      assert Enum.all?(aex9_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end

    test "it returns an error when invalid cursor", %{conn: conn} do
      cursor = "blah"
      error_msg = "invalid cursor: #{cursor}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9", cursor: cursor) |> json_response(400)
    end
  end

  describe "aex9_token" do
    test "it returns an aex9 token", %{conn: conn} do
      assert %{"contract_id" => @aex9_token_id} =
               conn |> get("/v2/aex9/#{@aex9_token_id}") |> json_response(200)
    end

    test "when not found, it returns 404", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not found: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/#{non_existent_id}") |> json_response(404)
    end

    test "when id is not valid, it returns 400", %{conn: conn} do
      invalid_id = "blah"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/#{invalid_id}") |> json_response(400)
    end
  end

  describe "aex9_token_balances" do
    test "it returns the paginated balances of an aex9 contract", %{conn: conn} do
      limit = 1

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}/balances", limit: limit)
               |> json_response(200)

      balances_accounts =
        balances |> Enum.map(fn %{"account" => account} -> account end) |> Enum.reverse()

      assert ^limit = length(balances)
      assert ^balances_accounts = Enum.sort(balances_accounts)

      if next do
        assert %{"data" => next_balances, "prev" => prev} =
                 conn |> get(next) |> json_response(200)

        next_balances_accounts =
          next_balances |> Enum.map(fn %{"account" => account} -> account end) |> Enum.reverse()

        assert ^limit = length(next_balances)
        assert ^next_balances_accounts = Enum.sort(next_balances_accounts)

        assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
      end
    end

    test "returns the empty amounts for aex9 contract without balance", %{conn: conn} do
      contract_id = "ct_U7whpYJo4xXoXjEpw39mWEPKgKM2kgSZk9em5FLK8Xq2FrRWE"

      assert %{"data" => [], "next" => nil} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances")
               |> json_response(200)
    end

    test "when not an aex9 contract, it returns an error", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not AEX9 contract: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/#{non_existent_id}/balances") |> json_response(400)
    end
  end

  describe "aex9_token_balance" do
    test "it returns an aex9 token balance", %{conn: conn} do
      assert %{"contract" => @aex9_token_id, "account" => @aex9_token_account_id} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}/balances/#{@aex9_token_account_id}")
               |> json_response(200)
    end

    test "when contract not AEX9, it returns an error", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      account_id = @aex9_token_account_id
      error_msg = "not AEX9 contract: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{non_existent_id}/balances/#{account_id}")
               |> json_response(400)
    end

    test "when account not found, it returns nil as amount", %{conn: conn} do
      non_existent_account_id = "ak_9MsbDuBTtKegKpj5uSxfPwmJ4YiN6bBdtXici682DgPk8ycpM"

      assert %{"amount" => nil} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}/balances/#{non_existent_account_id}")
               |> json_response(200)
    end

    test "when id is not valid, it returns 400", %{conn: conn} do
      invalid_id = "blah"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{invalid_id}/balances/#{@aex9_token_account_id}")
               |> json_response(400)
    end
  end

  describe "aex9_account_balances" do
    test "it returns all of the account balances from the different tokens", %{conn: conn} do
      limit = 3

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/account-balances/#{@aex9_token_account_id}", limit: limit)
               |> json_response(200)

      balances_heights =
        balances |> Enum.map(fn %{"height" => height} -> height end) |> Enum.reverse()

      assert ^limit = length(balances)
      assert ^balances_heights = Enum.sort(balances_heights)

      if next do
        assert %{"data" => next_balances, "prev" => prev} =
                 conn |> get(next) |> json_response(200)

        next_balances_heights =
          next_balances |> Enum.map(fn %{"height" => account} -> account end) |> Enum.reverse()

        assert ^limit = length(next_balances)
        assert ^next_balances_heights = Enum.sort(next_balances_heights)
        assert Enum.at(balances_heights, limit - 1) >= Enum.at(next_balances_heights, 0)

        assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
      end
    end
  end

  describe "aex9_token_balance_history" do
    test "it returns the paginated balances of an aex9 contract for a given account", %{
      conn: conn
    } do
      limit = 3

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}/balances/#{@aex9_token_account_id}/history",
                 limit: limit
               )
               |> json_response(200)

      balances_heights =
        balances |> Enum.map(fn %{"height" => height} -> height end) |> Enum.reverse()

      assert ^limit = length(balances)
      assert ^balances_heights = Enum.sort(balances_heights)

      if next do
        assert %{"data" => next_balances, "prev" => prev} =
                 conn |> get(next) |> json_response(200)

        next_balances_accounts =
          next_balances |> Enum.map(fn %{"account" => account} -> account end) |> Enum.reverse()

        assert ^limit = length(next_balances)
        assert ^next_balances_accounts = Enum.sort(next_balances_accounts)

        assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
      end
    end

    test "it returns the paginated balances of an aex9 contract for a given account and a given scope",
         %{conn: conn} do
      limit = 3
      first = 500_000
      last = 600_000

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}/balances/#{@aex9_token_account_id}/history",
                 scope: "gen:#{first}-#{last}",
                 limit: limit
               )
               |> json_response(200)

      balances_heights = Enum.map(balances, fn %{"height" => height} -> height end)

      assert ^limit = length(balances)
      assert ^balances_heights = Enum.sort(balances_heights)
      assert Enum.at(balances_heights, 0) >= first
      assert Enum.at(balances_heights, limit - 1) <= last
    end
  end
end
