defmodule Devmode.AeMdwWeb.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :devmode

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.DevmodeHelpers
  alias AeMdw.Sync.Watcher

  setup_all do
    Watcher.start_sync()
    Process.sleep(2_000)
  end

  describe "calls" do
    test "it gets a contract's calls", %{conn: conn} do
      %{
        "accounts" => [sender_address, recipient_address | _rest],
        "contracts" => [contract1, contract2 | _rest2]
      } = DevmodeHelpers.output()

      assert %{"data" => [amount_call, chain_create_call | _rest]} =
               conn
               |> get("/v2/contracts/calls", contract: contract1, direction: "forward")
               |> json_response(200)

      assert %{
               "function" => "Call.amount",
               "internal_tx" => %{"type" => "SpendTx"}
             } = amount_call

      assert %{
               "function" => "Call.create",
               "internal_tx" => %{"type" => "ContractCreateTx"}
             } = chain_create_call
    end
  end

  describe "contract" do
    test "it fetches contracts created via ContractCreateTx", %{conn: conn} do
      %{"accounts" => [account1 | _rest], "contracts" => [contract1, contract2 | _rest2]} =
        DevmodeHelpers.output()

      {:contract_pubkey, contract1_pk} = Enc.decode(contract1)
      contract_account1 = Enc.encode(:account_pubkey, contract1_pk)

      assert %{"source_tx_type" => "ContractCreateTx", "create_tx" => %{"owner_id" => ^account1}} =
               conn
               |> get("/v2/contracts/#{contract1}", contract: contract1)
               |> json_response(200)

      assert %{
               "source_tx_type" => "ContractCallTx",
               "create_tx" => %{"owner_id" => ^contract_account1}
             } =
               conn
               |> get("/v2/contracts/#{contract2}", contract: contract1)
               |> json_response(200)
    end
  end
end
