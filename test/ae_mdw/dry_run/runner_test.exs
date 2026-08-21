defmodule AeMdw.DryRun.RunnerTest do
  use ExUnit.Case

  import Mock

  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.DryRun.Runner

  @contract_pk <<1::256>>
  @block_hash <<2::256>>
  @height 500_000
  @introspection_methods ["meta_info", "aex9_extensions", "aex141_extensions"]

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

    test "gives the AEX-N introspection calls an execution budget, not the call tx base gas" do
      test_pid = self()

      protocol = :aec_hard_forks.protocol_effective_at_height(@height)
      call_tx_base_gas = :aec_governance.tx_base_gas(:contract_call_tx, protocol, 3)

      with_mock :aec_dry_run, [:passthrough],
        dry_run: fn _block_hash, _accounts, [{:tx, aetx}], _opts ->
          send(test_pid, {:dry_run_tx, aetx})

          {:error, "not executed"}
        end do
        for function_name <- @introspection_methods do
          assert {:error, :dry_run_error} =
                   Runner.call_contract(
                     @contract_pk,
                     {:key, @height, @block_hash},
                     function_name,
                     []
                   )

          assert_received {:dry_run_tx, aetx}
          assert {:contract_call_tx, call_tx} = :aetx.specialize_type(aetx)

          gas = :aect_call_tx.gas(call_tx)

          assert gas == 6_000_000
          assert gas > call_tx_base_gas
        end
      end
    end
  end
end
