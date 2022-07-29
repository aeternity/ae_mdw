defmodule AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  alias AeMdw.AsyncTaskTestUtil
  alias AeMdw.Db.Aex9BalancesCache
  alias AeMdw.Sync.AsyncTasks

  import Mock

  test "enqueue and dequeue" do
    contract_pk = :crypto.strong_rand_bytes(32)
    {kbi, mbi} = block_index = {543_210, 10}
    kb_hash = :crypto.strong_rand_bytes(32)
    next_mb_hash = :crypto.strong_rand_bytes(32)

    Aex9BalancesCache.put(contract_pk, block_index, next_mb_hash, %{
      {:address, :crypto.strong_rand_bytes(32)} => <<>>
    })

    with_mocks [
      {AeMdw.Node.Db, [],
       [
         get_key_block_hash: fn height ->
           assert height == kbi + 1
           kb_hash
         end,
         get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end
       ]}
    ] do
      AsyncTasks.Supervisor.start_link([])

      AsyncTasks.Producer.enqueue(
        :update_aex9_state,
        [contract_pk],
        [
          block_index,
          Enum.random(1_000_000..99_000_000)
        ],
        only_new: true
      )

      AsyncTaskTestUtil.wakeup_consumers()

      assert Enum.any?(1..20, fn _i ->
               Process.sleep(50)
               %{dequeue_buffer: []} == :sys.get_state(AsyncTasks.Producer)
             end)
    end
  end
end
