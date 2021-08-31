defmodule AeMdw.Db.Setup do
  require AeMdw.Db.Model
  alias AeMdw.Db.Model

  def create_table(name),
    do: :mnesia.create_table(name, tab_def(name, mode()))

  def create_tables(),
    do: create_tables(mode())

  def create_tables(mode),
    do: missing_tables(mode) |> Enum.map(&create_table!/1)

  def handle_issues(xs),
    do: xs |> Enum.map(&handle_issue(&1, mode()))

  def delete_tables(),
    do: Model.tables() |> delete_tables

  def delete_tables(tables),
    do: tables |> Enum.map(&{&1, :mnesia.delete_table(&1)})

  def clear_tables(),
    do: Model.tables() |> Enum.map(&:mnesia.clear_table/1)

  def check_tables(acc) do
    case check_tables() do
      [] -> []
      issues -> [{:callback, {__MODULE__, :handle_issues, [issues]}}]
    end ++ acc
  end

  def tab_defs(mode),
    do: Model.tables() |> Enum.map(&tab_def(&1, mode))

  def tab_def(name, mode),
    do: tab_def(name, :ordered_set, mode)

  defp tab_def(table, type, mode) do
    record = Model.record(table)

    {table,
     [
       :aec_db.tab_copies(mode)
       | [
           type: type,
           record_name: record,
           attributes: Model.fields(record),
           user_properties: [vsn: 1]
         ]
     ]}
  end

  defp check_table({name, definition}, acc),
    do: :aec_db.check_table(name, definition, acc)

  defp create_table!({name, definition}),
    do: {name, {:atomic, :ok} = :mnesia.create_table(name, definition)}

  defp handle_issue({:missing_table, name}, mode),
    do: create_table!(tab_def(name, mode))

  def missing_tables(),
    do: missing_tables(mode())

  def missing_tables(mode),
    do: for({:missing_table, name} <- check_tables(), do: tab_def(name, mode))

  def mode,
    do: :aec_db.backend_mode()

  def check_tables(),
    do: tab_defs(mode()) |> Enum.reduce([], &check_table/2)
end
