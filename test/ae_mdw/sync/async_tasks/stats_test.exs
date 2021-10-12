defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Util
  alias AeMdw.Sync.AsyncTasks.Stats

  @task_type :update_aex9_presence
  @contract_pk "ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo"
  @account_pk "ak_2CuCtmoExsuW7iG5BbRAoncSZAoZt8Abu21qrPUhqfFNin75iL"

  test "update/2 and counter/0 success without pending db records" do
    assert Stats.update(10, 100) == :ok
    assert Stats.counters() == %{producer_buffer: 10, total_pending: 0}
  end

  test "with pending db records" do
    :mnesia.transaction(fn ->
      delete_after? = not Contract.aex9_presence_exists?(@contract_pk, @account_pk)
      setup_delete_aex9_presence(@contract_pk, @account_pk)
      # enqueue and quickly dequeue before any Consumer
      args = [@contract_pk, @account_pk]
      assert not Store.is_enqueued?(@task_type, args)
      Producer.enqueue(@task_type, args)
      assert Store.is_enqueued?(@task_type, args)
      assert Model.async_tasks(index: index, args: ^args) = task = Producer.dequeue()
      assert Util.read(Model.AsyncTasks, index) == [task]

      # discard task as if processed
      Producer.notify_consumed(index)
      assert nil == Producer.dequeue()

      # enqueue and check that was processed
      Producer.enqueue(@task_type, args)
      Process.sleep(1000)
      assert Util.read(Model.AsyncTasks, index) == []
      assert Contract.aex9_presence_exists?(@contract_pk, @account_pk)

      if delete_after?, do: setup_delete_aex9_presence(@contract_pk, @account_pk)
    end)
  end

  defp setup_delete_aex9_presence(contract_pk, account_pk) do
    Util.do_dels([{Model.Aex9AccountPresence, [{account_pk, -1, contract_pk}]}])
  end
end
