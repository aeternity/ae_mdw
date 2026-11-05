defmodule AeMdw.Sync.AsyncStoreServerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Stats
  alias AeMdw.Sync.AsyncStoreServer

  require Model

  describe "flush_mutations/1" do
    test "returns once a commit ran the mutations" do
      contract_pk = :crypto.strong_rand_bytes(32)
      key = Stats.aex9_holder_count_key(contract_pk)
      m_stat = Model.stat(index: key, payload: 5)
      on_exit(fn -> Database.dirty_delete(Model.Stat, key) end)

      task =
        Task.async(fn ->
          AsyncStoreServer.flush_mutations([WriteMutation.new(Model.Stat, m_stat)])
        end)

      wait_for_waiter()

      assert nil == Task.yield(task, 100)
      assert :not_found = State.get(State.new(), Model.Stat, key)

      assert %State{} = AsyncStoreServer.write_async_store(State.new())

      assert :ok = Task.await(task)
      assert {:ok, ^m_stat} = State.get(State.new(), Model.Stat, key)
    end
  end

  defp wait_for_waiter do
    Enum.find(1..100, fn _i ->
      Process.sleep(10)
      match?(%{flush_waiters: [_waiter]}, :sys.get_state(AsyncStoreServer))
    end) || flunk("the flush mutations weren't queued")
  end
end
