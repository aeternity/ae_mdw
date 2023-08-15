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
    next_height = Enum.random(100_000..999_999)
    block_index = {next_height - 1, 10}
    kb_hash = :crypto.strong_rand_bytes(32)
    next_mb_hash = :crypto.strong_rand_bytes(32)

    Aex9BalancesCache.put(contract_pk, block_index, next_mb_hash, %{
      {:address, :crypto.strong_rand_bytes(32)} => <<>>
    })

    with_mocks [
      {AeMdw.Node.Db, [:passthrough],
       [
         get_key_block_hash: fn ^next_height ->
           Process.sleep(1_000)
           kb_hash
         end,
         get_next_hash: fn ^kb_hash, _mbi -> next_mb_hash end
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

      consumer_pid = AsyncTaskTestUtil.wakeup_consumer(2)

      task_pid1 =
        Enum.reduce_while(1..100, nil, fn _i, _acc ->
          Process.sleep(10)

          case :sys.get_state(consumer_pid) do
            %{task: %Task{pid: task_pid}} -> {:halt, task_pid}
            _no_task -> {:cont, nil}
          end
        end)

      Process.exit(task_pid1, :kill)

      assert Enum.reduce_while(1..100, false, fn _i, _acc ->
               Process.sleep(10)

               case :sys.get_state(consumer_pid) do
                 %{task: %Task{pid: task_pid}} when task_pid == task_pid1 ->
                   {:cont, false}

                 _no_task ->
                   {:halt, true}
               end
             end)
    end
  end
end
