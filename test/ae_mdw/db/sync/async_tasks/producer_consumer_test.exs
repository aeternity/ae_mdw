defmodule AeMdw.Sync.AsyncTasks.ProducerConsumerTest do
  use ExUnit.Case

  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Validate

  @task_type :update_aex9_presence
  @contract_pk Validate.id!("ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo")

  test "enqueue and dequeue" do
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

    Process.sleep(500)
    assert %{dequeue_buffer: []} = :sys.get_state(Producer)
  end
end
