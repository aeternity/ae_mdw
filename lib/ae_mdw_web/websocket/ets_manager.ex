defmodule AeMdwWeb.Websocket.EtsManager do
  def init_ordered(name), do: :ets.new(name, [:public, :ordered_set, :named_table])
  def init_duplicate_bag(name), do: :ets.new(name, [:public, :duplicate_bag, :named_table])

  def put(table, key, val),
    do: :ets.insert(table, {key, val})

  def get(table, key), do: :ets.lookup(table, key)

  def foldl(table, acc, fun), do: :ets.foldl(fun, acc, table)

  def is_member?(table, key), do: :ets.member(table, key)

  def delete(table, key), do: :ets.delete(table, key)

  def delete_object(table, {key, value}), do: :ets.delete_object(table, {key, value})

  def delete_all_objects(table), do: :ets.delete_all_objects(table)

  def delete_all_objects_for_tables(list),
    do: Enum.each(list, fn table -> delete_all_objects(table) end)

  def delete_obj_cht_tch(channel_targets, target_channels, pid) do
    case get(channel_targets, pid) do
      v ->
        Enum.each(v, fn {p, target} ->
          target_channels
          |> get(target)
          |> Enum.each(fn {k, p} ->
            if p == pid, do: delete_object(target_channels, {k, p})
          end)

          delete_object(channel_targets, {p, target})
        end)
    end
  end

  def delete_obj_tch_cht(target_channels, channel_targets, id) do
    target_channels
    |> get(id)
    |> Enum.each(fn {k, p} ->
      if k == id do
        channel_targets
        |> get(p)
        |> Enum.each(fn {pid, target} ->
          if pid == self() && target == id do
            delete_object(target_channels, {k, p})
            delete_object(channel_targets, {p, k})
          end
        end)
      end
    end)
  end
end
