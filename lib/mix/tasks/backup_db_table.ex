defmodule Mix.Tasks.BackupDbTable do
  use Mix.Task

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Mnesia

  @backup_suffix "Bkp"
  @chunk_size 10_000
  @sync_threshold 50_000

  def set_sync_threshold,
    do: Application.put_env(:mnesia, :dump_log_write_threshold, @sync_threshold)

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

    {:ok, record_name} = create_backup_table(table, backup_table)

    IO.puts("backing up #{record_name} records into #{backup_table}...")
    record_count = copy_records(table, backup_table)
    IO.puts("backup done for #{record_count} records.")

    System.stop(0)
  end

  def copy_records(source_table, dest_table) do
    {records_chunk, select_cont} = Util.select(source_table, [{:"$1", [], [:"$1"]}], @chunk_size)
    initial_count = sync_write_chunk(dest_table, records_chunk)
    stream_count = sync_write_stream(dest_table, select_cont)
    initial_count + stream_count
  end

  defp sync_write_stream(table_atom, select_cont) do
    Stream.resource(
      fn -> select_cont end,
      fn cont ->
        case Util.select(cont) do
          {chunk, cont} ->
            {[chunk], cont}

          :"$end_of_table" ->
            {:halt, nil}
        end
      end,
      fn nil -> nil end
    )
    |> Stream.map(fn records_chunk ->
      write_count = sync_write_chunk(table_atom, records_chunk)
      IO.puts("#{write_count}")
      write_count
    end)
    |> Enum.sum()
  end

  defp sync_write_chunk(table_atom, records) do
    :mnesia.sync_dirty(fn ->
      Enum.each(records, &(:ok = Mnesia.write(table_atom, &1)))
    end)

    length(records)
  end

  def table_atom(table_str), do: Enum.find(Model.tables(), &(Atom.to_string(&1) == table_str))

  def backup_table(table) do
    table
    |> Atom.to_string()
    |> Kernel.<>(@backup_suffix)
    |> String.to_atom()
  end

  def create_backup_table(table, backup_table) do
    :mnesia.delete_table(backup_table)

    record_name = Model.record(table)

    {:atomic, :ok} =
      :mnesia.create_table(backup_table,
        record_name: record_name,
        attributes: Model.fields(record_name),
        local_content: true,
        type: :ordered_set,
        disc_copies: [Node.self()]
      )

    {:ok, record_name}
  end
end
