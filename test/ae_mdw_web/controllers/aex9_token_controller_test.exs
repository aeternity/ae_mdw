defmodule AeMdwWeb.Aex9TokenControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Database
  alias AeMdw.Db.Model

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  require Model

  @default_limit 10
  @aex9_token_id enc_ct(<<1::256>>)

  setup_all _context do
    Enum.each(1..25, fn i ->
      meta_info = {name, symbol, _decimals} = {"some-AEX9-#{i}", "SAEX9#{i}", i}
      txi = 1_000 - i
      m_aex9 = Model.aexn_contract(index: {:aex9, <<i::256>>}, txi: txi, meta_info: meta_info)
      m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, <<i::256>>})
      m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, <<i::256>>})
      Database.dirty_write(Model.AexnContract, m_aex9)
      Database.dirty_write(Model.AexnContractName, m_aexn_name)
      Database.dirty_write(Model.AexnContractSymbol, m_aexn_symbol)
    end)

    :ok
  end

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
      prefix = "some-AEX"

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
      prefix = "SAEX9"

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
end
