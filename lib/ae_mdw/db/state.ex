defmodule AeMdw.Db.State do
  @moduledoc """
  Represents the overall state of the database, regardless of where it is being
  stored. This state can be updated in any way, but it's supposed to be done immutably -
  every change in the state returns a new one.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.Store
  alias AeMdw.Db.TxnDbStore

  defstruct [:store, :stats, :cache]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep direction() :: Database.direction()
  @typep table() :: Database.table()
  @typep stat_name() :: atom()
  @typep stats() :: %{atom() => non_neg_integer()}
  @typep cache_name() :: atom()

  @opaque t() :: %__MODULE__{
            store: Store.t(),
            stats: stats(),
            cache: %{cache_name() => map()}
          }

  @spec new() :: t()
  def new, do: %__MODULE__{store: DbStore.new(), stats: %{}, cache: %{}}

  @spec commit(t(), [Mutation.t()]) :: t()
  def commit(%__MODULE__{store: prev_store} = state, mutations) do
    state3 =
      TxnDbStore.transaction(fn store ->
        state2 = %__MODULE__{state | store: store}

        mutations
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(state2, &Mutation.execute/2)
      end)

    %__MODULE__{state3 | store: prev_store}
  end

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{store: store} = state, tab, record),
    do: %__MODULE__{state | store: Store.put(store, tab, record)}

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{store: store}, table, key), do: Store.get(store, table, key)

  @spec fetch!(t(), table(), key()) :: record() | :not_found
  def fetch!(state, table, key) do
    case get(state, table, key) do
      {:ok, record} -> record
      :not_found -> raise "#{inspect(key)} not found in #{table}"
    end
  end

  @spec count_keys(t(), table()) :: Enumerable.t()
  def count_keys(%__MODULE__{store: store}, table), do: Store.count_keys(store, table)

  @spec exists?(t(), table(), key()) :: boolean()
  def exists?(state, table, key), do: match?({:ok, _record}, get(state, table, key))

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{store: store} = state, tab, key),
    do: %__MODULE__{state | store: Store.delete(store, tab, key)}

  @spec next(t(), table(), key()) :: {:ok, key()} | :none
  def next(%__MODULE__{store: store}, table, key), do: Store.next(store, table, key)

  @spec prev(t(), table(), key()) :: {:ok, key()} | :none
  def prev(%__MODULE__{store: store}, table, key), do: Store.prev(store, table, key)

  @spec next(t(), table(), direction(), key()) :: {:ok, key()} | :none
  def next(state, table, :backward, cursor), do: prev(state, table, cursor)

  def next(state, table, :forward, cursor), do: next(state, table, cursor)

  @spec inc_stat(t(), stat_name(), integer()) :: t()
  def inc_stat(state, name, delta \\ 1)

  def inc_stat(%__MODULE__{stats: stats} = state, name, delta) do
    new_stats = Map.update(stats, name, delta, &(&1 + delta))

    %__MODULE__{state | stats: new_stats}
  end

  @spec get_stat(t(), stat_name(), term()) :: integer()
  def get_stat(%__MODULE__{stats: stats}, name, default), do: Map.get(stats, name, default)

  @spec clear_stats(t()) :: t()
  def clear_stats(state), do: %__MODULE__{state | stats: %{}}

  @spec cache_put(t(), cache_name(), term(), term()) :: t()
  def cache_put(%__MODULE__{cache: cache} = state, cache_name, key, value) do
    %__MODULE__{
      state
      | cache: Map.update(cache, cache_name, %{key => value}, &Map.put(&1, key, value))
    }
  end

  @spec cache_delete(t(), cache_name(), term()) :: t()
  def cache_delete(%__MODULE__{cache: cache} = state, cache_name, key) do
    %__MODULE__{
      state
      | cache: Map.update(cache, cache_name, %{}, &Map.delete(&1, key))
    }
  end

  @spec cache_get(t(), cache_name(), term()) :: {:ok, term()} | :not_found
  def cache_get(%__MODULE__{cache: cache}, cache_name, key) do
    with {:ok, cache_table} <- Map.fetch(cache, cache_name),
         {:ok, value} <- Map.fetch(cache_table, key) do
      {:ok, value}
    else
      :error -> :not_found
    end
  end
end
