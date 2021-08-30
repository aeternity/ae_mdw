defmodule Mix.Tasks.RestoreDbTable do
  use Mix.Task

  alias AeMdw.Db.Model

  import Mix.Tasks.BackupDbTable, except: [run: 1]

  def run(args) do
    set_sync_threshold()
    :net_kernel.start([:aeternity@localhost, :shortnames])
    :ae_plugin_utils.start_aecore()
    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)
    IO.puts("================================================================================")
    table = table_atom(hd(args))

    if nil == table do
      IO.puts(
        "Table #{table} does not exist. Use table atom like Elixir.AeMdw.Db.Model.ContractLog."
      )

      System.stop(1)
    end

    backup_table = backup_table(table)

    IO.puts("restoring #{Model.record(table)} records from #{backup_table}...")
    restore_count = copy_records(backup_table, table)
    :mnesia.delete_table(backup_table)
    IO.puts("backup restored for #{restore_count} records.")

    System.stop(0)
  end
end
