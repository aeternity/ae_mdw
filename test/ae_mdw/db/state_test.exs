defmodule AeMdw.Db.StateTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.Producer

  import Mock

  require Model

  describe "commit_mem" do
    test "it queues async tasks" do
      ct_pk = :crypto.strong_rand_bytes(32)
      block_index = {123_456, 2}
      call_txi = 12_345_678

      with_mocks [
        {Producer, [],
         commit_enqueued: fn -> :ok end, enqueue: fn _job, _dedup_args, _args -> :ok end}
      ] do
        state = State.enqueue(State.new(), :update_aex9_state, [ct_pk], [block_index, call_txi])

        State.commit_mem(state, [])

        assert [^block_index, ^call_txi] = Map.fetch!(state.jobs, {:update_aex9_state, [ct_pk]})

        assert_called(Producer.enqueue(:update_aex9_state, :_, :_))
        assert_called(Producer.commit_enqueued())
      end
    end
  end
end
