defmodule AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  require Model

  @aex9_token_id enc_ct(<<100::256>>)

  setup_all _context do
    Enum.each(100..125, fn i ->
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

  describe "by_name" do
    test "it gets aex9 tokens by name", %{conn: conn} do
      assert aex9_tokens = conn |> get("/aex9/by_name") |> json_response(200)
      assert length(aex9_tokens) > 0

      aex9_names = aex9_tokens |> Enum.map(fn %{"name" => name} -> name end)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert Enum.all?(aex9_tokens, fn %{
                                         "name" => name,
                                         "symbol" => symbol,
                                         "decimals" => decimals,
                                         "contract_txi" => txi,
                                         "contract_id" => contract_id
                                       } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(decimals) and
                        is_integer(txi)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "it gets aex9 tokens filtered by name prefix", %{conn: conn} do
      prefix = "some-AEX"

      assert aex9_tokens = conn |> get("/aex9/by_name", prefix: prefix) |> json_response(200)
      assert length(aex9_tokens) > 0
      assert Enum.all?(aex9_tokens, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
    end

    test "when invalid filters, it returns an error", %{conn: conn} do
      assert %{"error" => _error_msg} =
               conn |> get("/aex9/by_name", all: "") |> json_response(400)
    end
  end

  describe "by_symbol" do
    test "it gets aex9 tokens by symbol", %{conn: conn} do
      assert aex9_tokens = conn |> get("/aex9/by_symbol") |> json_response(200)

      aex9_symbols = aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert Enum.all?(aex9_tokens, fn %{
                                         "name" => name,
                                         "symbol" => symbol,
                                         "decimals" => decimals,
                                         "contract_txi" => txi,
                                         "contract_id" => contract_id
                                       } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(decimals) and
                        is_integer(txi)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "it gets aex9 tokens filtered by symbol prefix", %{conn: conn} do
      prefix = "SAEX9"

      assert aex9_tokens = conn |> get("/aex9/by_symbol", prefix: prefix) |> json_response(200)
      assert length(aex9_tokens) > 0

      assert Enum.all?(aex9_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end
  end

  describe "by_contract" do
    test "it returns an aex9 token", %{conn: conn} do
      assert %{"data" => %{"contract_id" => @aex9_token_id}} =
               conn |> get("/aex9/by_contract/#{@aex9_token_id}") |> json_response(200)
    end
  end
end
