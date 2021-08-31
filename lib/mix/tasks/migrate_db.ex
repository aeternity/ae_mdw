defmodule Mix.Tasks.MigrateDb do
  use Mix.Task

  require Ex2ms
  require Record

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  import Record, only: [defrecord: 2]

  # version is like 20210826171900 in 20210826171900_reindex_remote_logs.ex
  @record_name :migrations
  @defaults [version: -1, inserted_at: nil]

  defrecord @record_name, @defaults

  @fields for {k,_v} <- @defaults, do: k
  @version_len 14

  def run(_) do
    :net_kernel.start([:aeternity@localhost, :shortnames])
    :ae_plugin_utils.start_aecore()
    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)
    Log.info("================================================================================")
    exists? = Enum.find_value(:mnesia.system_info(:local_tables), false,
      fn table ->
        if table == Model.Migrations, do: true
      end)

    if not exists? do
      :mnesia.create_table(Model.Migrations,
        record_name: @record_name,
        attributes: @fields,
        local_content: true,
        type: :ordered_set,
        disc_copies: [Node.self()]
      )
    end

    version_spec = Ex2ms.fun do
      {_, version, _} -> version
    end

    max_version = Util.select(Model.Migrations, version_spec) |> Enum.max(fn -> -1 end)
    Log.info("current migration version: #{max_version}")

    "priv/migrations/*.ex"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      version =
        path
        |> Path.basename()
        |> String.slice(0..@version_len-1)

      {String.to_integer(version), path}
    end)
    |> Enum.sort_by(fn {version, _path} -> version end)
    |> Enum.each(fn {int_version, path} ->
      if int_version > max_version do
        [{module, _}] = Code.compile_file(path)
        Log.info("applying version #{int_version} with #{module}...")
        {:ok, _} = apply(module, :run, [])
        :mnesia.sync_dirty(fn ->
          :mnesia.write(Model.Migrations, {@record_name, int_version, DateTime.utc_now()}, :write)
        end)
        Log.info("applied version #{int_version}")
      else
        Log.info("version #{int_version} already applied")
      end
    end)
    :mnesia.dump_log()
    System.stop(0)
  end
end
