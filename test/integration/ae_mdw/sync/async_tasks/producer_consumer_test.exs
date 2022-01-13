defmodule Integration.AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Validate

  require Ex2ms
  require Model

  @task_type :update_aex9_presence
  @contract_pk Validate.id!("ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo")
  @account_pk Validate.id!("ak_2CuCtmoExsuW7iG5BbRAoncSZAoZt8Abu21qrPUhqfFNin75iL")

  test "enqueue, dequeue and aex9 presence update success" do
    # setup
    exists_before? =
      :mnesia.async_dirty(fn -> Contract.aex9_presence_exists?(@contract_pk, @account_pk) end)

    on_exit(fn ->
      if not exists_before?, do: setup_delete_aex9_presence(@contract_pk, @account_pk)
    end)

    if exists_before?, do: setup_delete_aex9_presence(@contract_pk, @account_pk)

    # check async enqueue and sync dequeue
    args = [@contract_pk]
    Producer.enqueue(@task_type, args)
    Producer.enqueue(@task_type, args)
    Producer.commit_enqueued()

    assert index =
             Enum.reduce_while(1..50, nil, fn _i, nil ->
               Process.sleep(20)
               task = Producer.dequeue()

               if task do
                 assert Model.async_tasks(index: index, args: ^args) = task
                 assert [task] == Util.read(Model.AsyncTasks, index)

                 {:halt, index}
               else
                 {:cont, nil}
               end
             end)

    # discard task as if processed
    Producer.notify_consumed(index, args, false)
    assert nil == Producer.dequeue()

    # enqueue and check that the async task was processed
    Producer.enqueue(@task_type, args)
    Producer.commit_enqueued()

    [{_id, pid, _type, _mod}] =
      AsyncTasks.Supervisor
      |> Supervisor.which_children()
      |> Enum.filter(fn {id, _pid, _type, _mod} ->
        id == "Elixir.AeMdw.Sync.AsyncTasks.Consumer1"
      end)

    assert Enum.reduce_while(1..50, false, fn _i, _acc ->
             Process.send(pid, :demand, [:noconnect])
             Process.sleep(100)

             exists? =
               :mnesia.async_dirty(fn ->
                 Contract.aex9_presence_exists?(@contract_pk, @account_pk)
               end)

             if exists?, do: {:halt, true}, else: {:cont, false}
           end)
  end

  defp setup_delete_aex9_presence(contract_pk, account_pk) do
    :mnesia.sync_dirty(fn ->
      :mnesia.delete(Model.Aex9AccountPresence, {account_pk, -1, contract_pk}, :write)
    end)
  end
end
