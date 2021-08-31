defmodule Mix.Tasks.MigrateDb do
  use Mix.Task

  require Ex2ms

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  @table Model.Migrations
  @record_name Model.record(@table)
  @version_len 14

  @migrations_code_path "priv/migrations/*.ex"

  def run(_) do
    :net_kernel.start([:aeternity@localhost, :shortnames])
    :ae_plugin_utils.start_aecore()
    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)
    Log.info("================================================================================")
    # create_migration_table()

    version_spec =
      Ex2ms.fun do
        {_, version, _} -> version
      end

    current_version = Util.select(@table, version_spec) |> Enum.max(fn -> -1 end)
    Log.info("current migration version: #{current_version}")

    @migrations_code_path
    |> list_migrations_modules()
    |> Enum.each(&maybe_apply_migration(&1, current_version))

    :mnesia.dump_log()
    System.stop(0)
  end

  # defp create_migration_table do
  #   exists? = Enum.find_value(:mnesia.system_info(:local_tables), false,
  #     fn table ->
  #       if table == @table, do: true
  #     end)

  #   if not exists? do
  #     Setup.create_table(@table)
  #   end
  #   |> IO.inspect()
  # end

  defp list_migrations_modules(path) do
    path
    |> Path.wildcard()
    |> Enum.map(fn path ->
      version =
        path
        |> Path.basename()
        |> String.slice(0..(@version_len - 1))

      {String.to_integer(version), path}
    end)
    |> Enum.sort_by(fn {version, _path} -> version end)
  end

  defp maybe_apply_migration({version, path}, current_version) do
    if version > current_version do
      [{module, _}] = Code.compile_file(path)
      Log.info("applying version #{version} with #{module}...")
      {:ok, _} = apply(module, :run, [])

      :mnesia.sync_dirty(fn ->
        :mnesia.write(@table, {@record_name, version, DateTime.utc_now()}, :write)
      end)

      Log.info("applied version #{version}")
    else
      Log.info("version #{version} already applied")
    end
  end
end
