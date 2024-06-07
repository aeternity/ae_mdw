defmodule Mix.Tasks.Gen.Migration do
  @moduledoc """
  Generates a new migration file.
  """
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator

  @impl true
  def run(args) do
    case OptionParser.parse!(args, strict: []) do
      {_opts, [name]} ->
        path = Path.join(:code.priv_dir(:ae_mdw), "migrations")
        base_name = "#{underscore(name)}.ex"
        file = Path.join(path, "#{timestamp()}_#{base_name}")
        unless File.dir?(path), do: create_directory(path)

        fuzzy_path = Path.join(path, "*_#{base_name}")

        if Path.wildcard(fuzzy_path) != [] do
          Mix.raise(
            "migration can't be created, there is already a migration file with name #{name}."
          )
        end

        # The :change option may be used by other tasks but not the CLI
        assigns = [
          mod: camelize(name)
        ]

        create_file(file, migration_template(assigns))

        file

      {_, _} ->
        Mix.raise(
          "expected gen.migration to receive the migration file name, " <>
            "got: #{inspect(Enum.join(args, " "))}"
        )
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  embed_template(:migration, """
  defmodule AeMdw.Migrations.<%= @mod %> do
    alias AeMdw.Db.State

    @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
    def run(state, _from_start?) do
      
    end
  end
  """)
end
