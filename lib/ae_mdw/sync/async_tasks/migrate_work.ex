defmodule AeMdw.Sync.AsyncTasks.MigrateWork do
  @moduledoc """
  Interface for migration processing modules that execute asynchronously.
  """

  defmodule Migration do
    @moduledoc """
    Mutation module, function and arguments to be executed.
    """
    @type t :: %__MODULE__{mutations_mfa: {atom(), atom(), list()}}

    defstruct mutations_mfa: {nil, nil, []}
  end

  @type migration :: %Migration{
          mutations_mfa: {module(), atom(), list()}
        }

  @callback process([migration], done_fn :: fun()) :: :ok
end
