defmodule AeMdw.DryRun.RunnerTest do
  use ExUnit.Case

  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.DryRun.Runner

  describe "call_contract/4" do
    test "returs error when contract does not exist" do
      assert {:error, :contract_does_not_exist} =
               Runner.call_contract(<<123_456::256>>, DBN.top_height_hash(false), "balances", [])
    end
  end
end
