defmodule AeMdw.Sync.EventHandlerTest do
  use ExUnit.Case

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Sync.EventHandler

  defmodule MockSpawner do
    @spec spawner_fn((() -> pid())) :: atom()
    def spawner_fn(_fun) do
      send(self(), :spawner_called)

      :some_pid
    end
  end

  describe "process_event/2" do
    test "when pid down, it clears the process and increases restarts until stopping" do
      {_db_store, _mem_store, event_handler} = build_event_handler()

      assert {:ok, event_handler2} = EventHandler.process_event({:new_height, 2}, event_handler)

      assert {:ok, event_handler3} =
               EventHandler.process_event({:pid_down, :some_pid, :reason}, event_handler2)

      assert {:ok, event_handler4} =
               EventHandler.process_event({:pid_down, :some_pid, :reason}, event_handler3)

      assert {:ok, event_handler5} =
               EventHandler.process_event({:pid_down, :some_pid, :reason}, event_handler4)

      assert {:ok, event_handler6} =
               EventHandler.process_event({:pid_down, :some_pid, :reason}, event_handler5)

      assert :stop = EventHandler.process_event({:pid_down, :some_pid, :reason}, event_handler6)
    end

    test "when new height and height < chain - mem gens, executes the db_sync and mem_sync" do
      {_db_store, _mem_store, event_handler} = build_event_handler()

      assert {:ok, event_handler2} = EventHandler.process_event({:new_height, 200}, event_handler)

      assert_received :spawner_called
      assert_received :spawner_called
    end

    test "when new height and chain - mem gems < height < chain - unsynced gens, executes the mem_sync only" do
      {_db_store, _mem_store, event_handler} = build_event_handler()

      assert {:ok, _event_handler2} = EventHandler.process_event({:new_height, 3}, event_handler)

      assert_received :spawner_called
      refute_received :spawner_called
    end

    test "when new height and chain - unsynced gens < height, executes the no sync" do
      {_db_store, _mem_store, event_handler} = build_event_handler()

      assert {:ok, _event_handler2} = EventHandler.process_event({:new_height, 0}, event_handler)

      refute_received :spawner_called
    end
  end

  defp build_event_handler do
    db_store = MemStore.new(NullStore.new())
    mem_store = MemStore.new(db_store)

    db_state = State.new(db_store)
    mem_state = State.new(mem_store)

    event_handler = EventHandler.init(0, db_state, mem_state, &MockSpawner.spawner_fn/1)

    {db_store, mem_store, event_handler}
  end
end
