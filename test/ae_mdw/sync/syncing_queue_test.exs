defmodule AeMdw.Sync.SyncingQueueTest do
  use ExUnit.Case, async: false

  alias AeMdw.Sync.SyncingQueue

  @tag :capture_log
  test "runs a failed task again before the tasks queued after it" do
    test_pid = self()
    task_fn = fn -> send(test_pid, :ran) end
    next_fn = fn -> :ok end
    ref = make_ref()

    assert {:noreply, {[^task_fn, ^next_fn], :retrying}} =
             SyncingQueue.handle_info(
               {:DOWN, ref, :process, self(), :boom},
               {[next_fn], {ref, task_fn}}
             )

    assert {:noreply, {[^next_fn], {_ref, ^task_fn}}} =
             SyncingQueue.handle_info(:retry, {[task_fn, next_fn], :retrying})

    assert_receive :ran
  end
end
