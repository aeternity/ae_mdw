defmodule AeMdw.Sync.AsyncTasks.ConsumerTest do
  use ExUnit.Case, async: false

  alias AeMdw.AsyncTaskTestUtil
  alias AeMdw.Sync.Aex9BalancesCache
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks

  import Mock

  require Model

  test "enqueue and dequeue with failed task" do
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
           Process.sleep(1_000)
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

      consumer_pid = AsyncTaskTestUtil.wakeup_consumer()

      task_pid1 =
        Enum.reduce_while(1..100, nil, fn _i, _acc ->
          Process.sleep(10)

          case :sys.get_state(consumer_pid) do
            %{task: %Task{pid: task_pid}} -> {:halt, task_pid}
            _no_task -> {:cont, nil}
          end
        end)

      Process.exit(task_pid1, :kill)

      assert Enum.any?(1..100, fn _i ->
               case :sys.get_state(consumer_pid) do
                 %{task: %Task{pid: task_pid2}} -> task_pid2 != task_pid1
                 _no_task -> false
               end
             end)
    end
  end
end
