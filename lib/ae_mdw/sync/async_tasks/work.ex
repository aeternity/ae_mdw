defmodule AeMdw.Sync.AsyncTasks.Work do
  @moduledoc """
  The interface for actual processing modules.
  """

  @callback process(args :: list(), done_fn :: fun()) :: :ok
end
