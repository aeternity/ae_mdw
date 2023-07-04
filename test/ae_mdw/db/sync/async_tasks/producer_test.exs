defmodule AeMdw.Sync.AsyncTasks.ProducerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Producer

  import Mock

  require Model

  test "save_enqueue/0" do
    args1 = [:crypto.strong_rand_bytes(32)]
    args2 = [:crypto.strong_rand_bytes(32)]

    {kbi, mbi} = block_index = {543_210, 10}
    extra_args1 = [block_index, Enum.random(1_000_000..99_000_000)]
    extra_args2 = [block_index, Enum.random(1_000_000..99_000_000)]

    kb_hash = :crypto.strong_rand_bytes(32)
    next_mb_hash = :crypto.strong_rand_bytes(32)

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
      Producer.enqueue(:update_aex9_state, args1, extra_args1, only_new: false)
      Producer.enqueue(:update_aex9_state, args2, extra_args2, only_new: false)
      Producer.save_enqueued()

      all_tasks =
        Model.AsyncTask
        |> Database.all_keys()
        |> Enum.map(&Database.fetch!(Model.AsyncTask, &1))

      assert [Model.async_task(index: task_index1), Model.async_task(index: task_index2)] =
               Enum.filter(all_tasks, fn Model.async_task(args: args, extra_args: extra_args) ->
                 {args, extra_args} in [{args1, extra_args1}, {args2, extra_args2}]
               end)

      Database.dirty_delete(Model.AsyncTask, task_index1)
      Database.dirty_delete(Model.AsyncTask, task_index2)
    end
  end
end
