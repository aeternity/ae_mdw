defmodule AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  # alias AeMdw.Sync.AsyncTasks.Consumer
  alias AeMdw.Sync.AsyncTasks.Producer
  # alias AeMdw.Sync.AsyncTasks.Supervisor, as: AsyncTasksSupervisor
  alias AeMdw.Validate

  require Ex2ms
  require Model

  @task_type :update_aex9_presence
  @contract_pk Validate.id!("ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo")
  @account_pk  Validate.id!("ak_2CuCtmoExsuW7iG5BbRAoncSZAoZt8Abu21qrPUhqfFNin75iL")

  test "enqueue, dequeue and aex9 presence update success" do
    # setup
    exists_before? = :mnesia.async_dirty(fn -> Contract.aex9_presence_exists?(@contract_pk, @account_pk, -1) end)
    if exists_before?, do: setup_delete_aex9_presence(@contract_pk, @account_pk)
    on_exit(fn ->
      if not exists_before?, do: setup_delete_aex9_presence(@contract_pk, @account_pk)
    end)

    # enqueue/dequeue
    args = [@contract_pk]
    Producer.enqueue(@task_type, args)
    assert Model.async_tasks(index: index, args: ^args) = task = Producer.dequeue()
    assert Util.read(Model.AsyncTasks, index) == [task]

    # discard task as if processed
    Producer.notify_consumed(index)
    assert nil == Producer.dequeue()

    # enqueue and check that was processed
    Producer.enqueue(@task_type, args)
    Process.sleep(1000)
    assert Util.read(Model.AsyncTasks, index) == []
    assert :mnesia.async_dirty(fn -> Contract.aex9_presence_exists?(@contract_pk, @account_pk) end)
  end

  defp setup_delete_aex9_presence(contract_pk, account_pk) do
    :mnesia.sync_dirty(fn -> :mnesia.delete(Model.Aex9AccountPresence, {account_pk, -1, contract_pk}, :delete) end)
  end
end
