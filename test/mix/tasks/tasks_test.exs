defmodule AeMdw.MixTasksTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias Mix.Tasks.BackupDbTable

  # on demand
  @tag :skip
  test "backup and restore db table" do
    table = Model.ContractLog
    backup_table = BackupDbTable.backup_table(table)
    {:ok, record_name} = BackupDbTable.create_backup_table(table, backup_table)

    IO.puts("testing backup for #{table} with #{record_name} records")

    records_before = Util.select(table, [{:"$1", [], [:"$1"]}])

    backup_count = BackupDbTable.copy_records(table, backup_table)
    assert backup_count == length(records_before)

    IO.puts("restoring ...")

    restore_count = BackupDbTable.copy_records(table, backup_table)
    assert restore_count == length(records_before)

    records_after = Util.select(table, [{:"$1", [], [:"$1"]}])
    assert records_after == records_before
  end
end
