defmodule AeMdw.Sync.AsyncTasks.UpdateTxStats do
  @moduledoc """
  Temporary module to get rid of pending tasks.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  @spec process(args :: list(), done_fn :: fun()) :: :ok
  def process(_args, done_fn) do
    _task = Task.async(done_fn)

    :ok
  end
end
