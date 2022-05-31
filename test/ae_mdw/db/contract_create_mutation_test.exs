defmodule AeMdw.Db.ContractCreateMutationTest do
  use ExUnit.Case, async: false

  import AeMdw.Node.ContractCallFixtures
  import Mock

  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Sync.AsyncTasks

  describe "execute" do
    test "creates contract with init aex9 log" do
      remote_pk = :crypto.strong_rand_bytes(32)
      remote_meta_info = {"aex9t", "AEX9t", 18}

      with_mocks [
        {
          AeMdw.Contract,
          [],
          [
            is_aex9?: fn ct_pk -> ct_pk == remote_pk end,
            aex9_meta_info: fn ct_pk -> ct_pk == remote_pk && {:ok, remote_meta_info} end
          ]
        }
      ] do
        AsyncTasks.Supervisor.start_link([])
        block_index = {492_393, 0}
        create_txi1 = 21_608_343
        call_rec1 = call_rec("no_log", remote_pk, create_txi1)

        state1 =
          State.commit(State.new(), [
            ContractCreateMutation.new(block_index, create_txi1, call_rec1),
            SyncContract.aex9_create_contract_mutation(remote_pk, block_index, create_txi1),
            Origin.origin_mutations(
              :contract_create_tx,
              nil,
              remote_pk,
              create_txi1,
              :crypto.strong_rand_bytes(32)
            )
          ])

        assert 1 == State.get_stat(state1, :contracts_created, 0)
        assert {:ok, create_txi1} == State.cache_get(state1, :ct_create_sync_cache, remote_pk)

        create_txi2 = create_txi1 + 1
        contract_pk = :crypto.strong_rand_bytes(32)
        call_rec2 = call_rec("remote_log", contract_pk, remote_pk, create_txi2)

        state2 =
          State.commit(state1, [ContractCreateMutation.new(block_index, create_txi2, call_rec2)])

        assert 2 == State.get_stat(state2, :contracts_created, 0)
        assert {:ok, create_txi2} == State.cache_get(state2, :ct_create_sync_cache, contract_pk)

        assert %{enqueue_buffer: enqueue_buffer} = :sys.get_state(AsyncTasks.Producer)

        assert Enum.any?(
                 enqueue_buffer,
                 &(&1 == {:update_aex9_state, [remote_pk], [block_index, create_txi2]})
               )
      end
    end
  end
end
