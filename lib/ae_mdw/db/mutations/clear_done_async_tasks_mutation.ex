defmodule AeMdw.Db.ClearDoneAsyncTasksMutation do
  @moduledoc """
  Deletes async tasks from in-memory or persisted state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.Store

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:delete_keys]

  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{}, state) do
    Store.list_done()
    |> Enum.reduce(state, fn task_index, state ->
      :ok = Store.clear_done(task_index)

      if State.exists?(state, Model.AsyncTask, task_index) do
        State.delete(state, Model.AsyncTask, task_index)
      else
        state
      end
    end)
  end
end
