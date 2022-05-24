defmodule AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Validate

  require Model

  @task_type :update_aex9_state
  @contract_pk Validate.id!("ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo")

  test "enqueue and dequeue" do
    args = [@contract_pk]
    extra_args = [{543_210, 10}, Enum.random(1_000_000..99_000_000)]
    AsyncTasks.Supervisor.start_link([])
    Producer.enqueue(@task_type, args, extra_args)
    Producer.commit_enqueued()

    Process.sleep(200)

    assert Model.AsyncTask
           |> Database.all_keys()
           |> Enum.map(&Database.fetch!(Model.AsyncTask, &1))
           |> Enum.any?(fn
             Model.async_task(args: ^args, extra_args: ^extra_args) -> true
             _other_task -> false
           end)

    AsyncTasks.Supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn {id, _pid, _type, _mod} ->
      is_binary(id) and String.starts_with?(id, "Elixir.AeMdw.Sync.AsyncTasks.Consumer")
    end)
    |> Enum.each(fn {_id, consumer_pid, _type, _mod} ->
      Process.send(consumer_pid, :demand, [:noconnect])
    end)

    Process.sleep(500)
    assert %{dequeue_buffer: []} = :sys.get_state(Producer)
  end
end
