defmodule AeMdw.Db.StepwiseStream do
  @moduledoc """
  Streams the keys of a Store by calling its next/prev once per key, for the stores
  that can't keep an iterator open for the whole stream.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Store

  @typep key() :: Database.key()
  @typep table() :: Database.table()
  @typep direction() :: Database.direction()

  @spec stream(Store.t(), table(), direction(), key() | nil) :: Enumerable.t()
  def stream(store, table, direction, start_key) do
    Stream.unfold(first_key(store, table, direction, start_key), fn
      :none -> nil
      {:ok, key} -> {key, next_key(store, table, direction, key)}
    end)
  end

  defp first_key(store, table, direction, nil), do: next_key(store, table, direction, nil)

  defp first_key(store, table, direction, key) do
    case Store.get(store, table, key) do
      {:ok, _record} -> {:ok, key}
      :not_found -> next_key(store, table, direction, key)
    end
  end

  defp next_key(store, table, :forward, key), do: Store.next(store, table, key)
  defp next_key(store, table, :backward, key), do: Store.prev(store, table, key)
end
