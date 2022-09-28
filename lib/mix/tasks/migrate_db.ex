defmodule Mix.Tasks.MigrateDb do
  @moduledoc """
  Executes new database migrations present in priv/migrations likewise Ecto.
  """
  use Mix.Task

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Log

  require Model

  @table Model.Migrations

  @version_len 14

  @migrations_code_path "priv/migrations/*.ex"

  # ignore for Code.compile_file/1
  @dialyzer {:no_return, run: 1}
  @dialyzer {:no_return, apply_migration!: 2}

  def run(from_startup?) when is_boolean(from_startup?), do: run([to_string(from_startup?)])

  @impl Mix.Task
  def run(args) do
    from_startup? = (List.first(args) || "false") |> String.to_existing_atom()

    if not from_startup? do
      {:ok, _pid} = :net_kernel.start([:aeternity@localhost, :shortnames])
      {:ok, _started_apps} = :ae_plugin_utils.start_aecore()
      :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
      :lager.set_loglevel(:lager_console_backend, :error)
    end

    Log.info("================================================================================")
    current_version = read_migration_version()
    Log.info("current migration version: #{current_version}")

    applied_count =
      current_version
      |> list_new_migrations()
      |> Enum.map(&apply_migration!(&1, from_startup?))
      |> length()

    if applied_count <= 0 do
      Log.info("migrations are up to date")
    end

    {:ok, applied_count}
  end

  @spec read_migration_version() :: integer()
  defp read_migration_version() do
    case Database.last_key(@table) do
      {:ok, version} -> version
      :none -> -1
    end
  end

  @spec list_new_migrations(integer()) :: [{integer(), String.t()}]
  defp list_new_migrations(current_version) do
    @migrations_code_path
    |> Path.wildcard()
    |> Enum.map(fn path ->
      version =
        path
        |> Path.basename()
        |> String.slice(0..(@version_len - 1))

      {String.to_integer(version), path}
    end)
    |> Enum.filter(fn {version, _path} -> version > current_version end)
    |> Enum.sort_by(fn {version, _path} -> version end)
  end

  @spec apply_migration!({integer(), String.t()}, boolean()) :: :ok
  defp apply_migration!({version, path}, from_startup?) do
    {module, _} =
      path
      |> Code.compile_file()
      |> List.last()

    Log.info("applying version #{version} with #{module}...")
    {:ok, _} = apply(module, :run, [from_startup?])

    Database.dirty_write(
      @table,
      Model.migrations(index: version, inserted_at: DateTime.utc_now())
    )

    Log.info("applied version #{version}")
    :ok
  end
end
