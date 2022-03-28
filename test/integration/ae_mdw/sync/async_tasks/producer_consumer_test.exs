defmodule Integration.AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Database
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Validate

  require Ex2ms
  require Model

  @task_type :update_aex9_presence
  @contract_pk Validate.id!("ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo")
  @account_pk Validate.id!("ak_2CuCtmoExsuW7iG5BbRAoncSZAoZt8Abu21qrPUhqfFNin75iL")

  test "enqueue, dequeue and aex9 presence update success" do
    create_txi = Origin.tx_index!({:contract, @contract_pk})
    # setup
    exists_before? = Contract.aex9_presence_exists?(@contract_pk, @account_pk, create_txi)

    on_exit(fn ->
      if not exists_before? do
        Database.dirty_delete(
          Model.Aex9AccountPresence,
          {@account_pk, create_txi, @contract_pk}
        )
      end
    end)

    if exists_before? do
      Database.dirty_delete(
        Model.Aex9AccountPresence,
        {@account_pk, create_txi, @contract_pk}
      )
    end

    # check async enqueue and sync dequeue
    args = [@contract_pk]
    AsyncTasks.Supervisor.start_link([])
    Producer.enqueue(@task_type, args)
    Producer.commit_enqueued()

    AsyncTasks.Supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn {id, _pid, _type, _mod} ->
      is_binary(id) and String.starts_with?(id, "Elixir.AeMdw.Sync.AsyncTasks.Consumer")
    end)
    |> Enum.each(fn {_id, consumer_pid, _type, _mod} ->
      Process.send(consumer_pid, :demand, [:noconnect])
    end)

    assert Enum.reduce_while(1..50, false, fn _i, _acc ->
             Process.sleep(100)

             if Contract.aex9_presence_exists?(@contract_pk, @account_pk, create_txi) do
               {:halt, true}
             else
               {:cont, false}
             end
           end)
  end
end
