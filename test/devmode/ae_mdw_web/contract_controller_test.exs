defmodule Devmode.AeMdwWeb.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :devmode

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.DevmodeHelpers
  alias AeMdw.Sync.Watcher
  alias AeMdw.Validate

  setup_all do
    Watcher.start_sync()
    Process.sleep(2_000)
  end

  describe "calls" do
    test "it gets a contract's calls", %{conn: conn} do
      %{"contracts" => [contract1, inner_contract1, contract2, inner_contract2 | _rest2]} =
        DevmodeHelpers.output()

      assert %{"data" => [amount_call, chain_create_call | _rest]} =
               conn
               |> get("/v2/contracts/calls", contract: contract1, direction: "forward")
               |> json_response(200)

      assert %{
               "function" => "Call.amount",
               "internal_tx" => %{
                 "type" => "SpendTx",
                 "sender_id" => account1,
                 "recipient_id" => inner_account1
               }
             } = amount_call

      assert ^contract1 = Enc.encode(:contract_pubkey, Validate.id!(account1))
      assert ^inner_contract1 = Enc.encode(:contract_pubkey, Validate.id!(inner_account1))

      assert %{
               "function" => "Call.create",
               "internal_tx" => %{"type" => "ContractCreateTx"}
             } = chain_create_call

      assert %{"data" => [amount_call2, chain_clone_call | _rest]} =
               conn
               |> get("/v2/contracts/calls", contract: contract2, direction: "forward")
               |> json_response(200)

      assert %{
               "function" => "Call.amount",
               "internal_tx" => %{
                 "type" => "SpendTx",
                 "sender_id" => account2,
                 "recipient_id" => inner_account2
               }
             } = amount_call2

      assert ^contract2 = Enc.encode(:contract_pubkey, Validate.id!(account2))
      assert ^inner_contract2 = Enc.encode(:contract_pubkey, Validate.id!(inner_account2))

      assert %{
               "function" => "Call.clone",
               "internal_tx" => %{"type" => "ContractCreateTx"}
             } = chain_clone_call
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
