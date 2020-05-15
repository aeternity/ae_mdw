defmodule AeMdwWeb.Websocket.EtsManager do
  def init(name), do: :ets.new(name, [:public, :ordered_set, :named_table])

  def put(table, key, val),
    do: :ets.insert(table, {key, val})

  def is_member?(table, key), do: :ets.member(table, key)

  def foldl(table, acc, fun), do: :ets.foldl(fun, acc, table)

  def delete(table, key), do: :ets.delete(table, key)

  def delete_all_objects(table), do: :ets.delete_all_objects(table)

  def delete_all_objects_in_all_tables(list), do: Enum.each(list, &delete_all_objects/1)

  def select_count(table, spec), do: :ets.select_count(table, spec)

  def select(table, spec), do: :ets.select(table, spec)

  def select_delete(table, spec), do: :ets.select_delete(table, spec)
end
