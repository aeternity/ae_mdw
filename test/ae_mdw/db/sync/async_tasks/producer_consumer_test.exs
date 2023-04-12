defmodule AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  alias AeMdw.AsyncTaskTestUtil
  alias AeMdw.Sync.Aex9BalancesCache
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks

  import Mock

  require Model

  test "enqueue and dequeue" do
    contract_pk = :crypto.strong_rand_bytes(32)
    {kbi, mbi} = block_index = {543_210, 10}
    kb_hash = :crypto.strong_rand_bytes(32)
    next_mb_hash = :crypto.strong_rand_bytes(32)

    Aex9BalancesCache.put(contract_pk, block_index, next_mb_hash, %{
      {:address, :crypto.strong_rand_bytes(32)} => 10
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

      call_txi = Enum.random(1_000_000..99_000_000)

      AsyncTasks.Producer.enqueue(
        :update_aex9_state,
        [contract_pk],
        [
          block_index,
          call_txi
        ],
        only_new: true
      )

      AsyncTaskTestUtil.wakeup_consumers()

      assert Enum.any?(1..20, fn _i ->
               Process.sleep(50)

               nil ==
                 AsyncTaskTestUtil.list_pending()
                 |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
                   args == [contract_pk] and extra_args == [block_index, call_txi]
                 end)
             end)
    end
  end
end
