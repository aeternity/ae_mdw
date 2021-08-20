defmodule AeMdw.Ets do
  def inc(table, key, delta \\ 1, init \\ 0)
      when is_number(delta) and is_number(init),
      do: diff(table, key, delta, init, &Kernel.+/2)

  def dec(table, key, delta \\ 1, init \\ 0)
      when is_number(delta) and is_number(init),
      do: diff(table, key, delta, init, &Kernel.-/2)

  def diff(table, key, delta, init, f) do
    old = get(table, key, init)
    set(table, key, f.(old, delta))
    old
  end

  def get(table, key, not_found_val \\ nil) do
    case :ets.lookup(table, key) do
      [{_, val}] -> val
      [] -> not_found_val
    end
  end

  def set(table, key, val \\ 0) do
    true = :ets.insert(table, [{key, val}])
    val
  end

  def foldl(table, init, f),
    do: :ets.foldl(f, init, table)

  def foldr(table, init, f),
    do: :ets.foldr(f, init, table)

  def to_map(table),
    do: foldl(table, %{}, fn {key, val}, acc -> Map.put(acc, key, val) end)

  def clear(table),
    do: :ets.delete_all_objects(table)
end
