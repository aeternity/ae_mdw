defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Stats

  require Model

  @contract_pk "ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo"

  describe "update/2 and counter/0 success" do
    test "without pending db records" do
      assert Stats.update(10, 100) == :ok
      assert Stats.counters() == %{producer_buffer: 10, total_pending: 0}
    end

    test "with pending db records" do
      :mnesia.transaction(fn ->
        db_pending_count = 50
        # setup
        indexes_to_clean =
          Enum.map(1..db_pending_count, fn i ->
            index = {System.system_time() + i, :update_aex9_presence}
            m_task = Model.async_tasks(index: index, args: [@contract_pk, <<i::256>>])
            :mnesia.write(Model.AsyncTasks, m_task, :write)
            index
          end)

        assert Stats.update(10, 100) == :ok
        assert Stats.counters() == %{producer_buffer: 10, total_pending: db_pending_count}

        # clean setup
        Enum.each(indexes_to_clean, fn index ->
          :mnesia.delete(Model.AsyncTasks, index, :delete)
        end)
      end)
    end
  end
end
