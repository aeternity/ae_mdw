defmodule Mix.Tasks.ResetDb do
  use Mix.Task

  def run(_) do
    :net_kernel.start([:aeternity@localhost, :shortnames])
    :ae_plugin_utils.start_aecore()
    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)
    IO.puts("================================================================================")
    mnesia_dir = to_string(Application.fetch_env!(:mnesia, :dir))
    tables = AeMdw.Db.Model.tables()
    table_dirs = Path.wildcard(mnesia_dir <> "/**/Elixir.AeMdw.*")
    IO.puts("removing tables from DB schema:")
    Enum.each(tables, &IO.puts("    #{&1}: #{inspect(:mnesia.delete_table(&1))}"))
    IO.puts("\nremoving DB directories:")
    Enum.each(table_dirs, &IO.puts("    #{&1}: #{inspect(File.rm_rf(&1))}"))
    System.stop(0)
  end
end
