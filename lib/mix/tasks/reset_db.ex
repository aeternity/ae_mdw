defmodule Mix.Tasks.ResetDb do
  @moduledoc """
  Removes MDW database directory.
  """

  use Mix.Task

  alias AeMdw.Db.RocksDb

  @spec run(any()) :: :ok
  def run(_args) do
    :ok = RocksDb.close()
    dir = Application.fetch_env!(:ae_mdw, RocksDb)[:data_dir]
    {:ok, _list} = File.rm_rf(dir)

    :ok
  end
end
