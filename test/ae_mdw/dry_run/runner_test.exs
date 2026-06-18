defmodule AeMdw.DryRun.RunnerTest do
  use ExUnit.Case

  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.DryRun.Runner

  setup_all do
    # Maintenance-mode boot skips aec_db:put_backend_module/1, so any test
    # that reaches :aec_db.get_backend_module/0 (here via top_height_hash/1)
    # crashes unless the persistent_term is seeded.
    :persistent_term.put({:aec_db, :backend_module}, "rocksdb")
    :ok
  end

  describe "call_contract/4" do
    test "returs error when contract does not exist" do
      assert {:error, :contract_does_not_exist} =
               Runner.call_contract(<<123_456::256>>, DBN.top_height_hash(false), "balances", [])
    end
  end
end
