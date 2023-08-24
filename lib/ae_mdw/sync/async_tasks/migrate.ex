defmodule AeMdw.Sync.AsyncTasks.Migrate do
  @moduledoc """
  Get and store account balance.
  """
  @behaviour AeMdw.Sync.AsyncTasks.MigrateWork

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncStoreServer
  alias AeMdw.Sync.AsyncTasks.MigrateWork.Migration

  require Model

  @spec process([MigrateWork.migration()], done_fn :: fun()) :: :ok
  def process(migrations, done_fn) do
    Enum.each(migrations, fn %Migration{mutations_mfa: {module, mutations_fn, params}} ->
      module
      |> apply(mutations_fn, params)
      |> AsyncStoreServer.write_mutations(done_fn)
    end)

    :ok
  end
end
