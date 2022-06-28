defmodule AeMdw.Db.State do
  @moduledoc """
  Represents the overall state of the database, regardless of where it is being
  stored. This state can be updated in any way, but it's supposed to be done immutably -
  every change in the state returns a new one.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.Store
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Db.Util, as: DbUtil

  defstruct [:store, :stats, :cache, :prev_states]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep direction() :: Database.direction()
  @typep table() :: Database.table()
  @typep stat_name() :: atom()
  @typep cache_name() :: atom()
  @typep height() :: Blocks.height()

  @opaque t() :: %__MODULE__{
            store: Store.t(),
            stats: %{stat_name() => non_neg_integer()},
            cache: %{cache_name() => map()},
            prev_states: [{Blocks.height(), t()}]
          }

  @state_pm_key :global_state

  @spec new(Store.t()) :: t()
  def new(store \\ DbStore.new()),
    do: %__MODULE__{store: store, stats: %{}, cache: %{}, prev_states: []}

  @spec height(t()) :: height()
  def height(state), do: DbUtil.synced_height(state)

  @spec commit(t(), [Mutation.t()]) :: t()
  def commit(%__MODULE__{store: prev_store} = state, mutations) do
    new_state =
      TxnDbStore.transaction(fn store ->
        state2 = %__MODULE__{state | store: store}

        mutations
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(state2, &Mutation.execute/2)
      end)

    %__MODULE__{new_state | store: prev_store}
  end

  @spec commit_db(t(), [Mutation.t()]) :: t()
  def commit_db(state, mutations), do: commit(state, mutations)

  @spec commit_mem(t(), [Mutation.t()]) :: t()
  def commit_mem(state, mutations) do
    state2 =
      mutations
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(state, &Mutation.execute/2)

    height = DbUtil.synced_height(state2)
    state3 = add_prev_state(state2, height, state)

    set_global(state3)

    state3
  end

  @spec set_global(t()) :: t()
  def set_global(state) do
    :persistent_term.put(@state_pm_key, state)

    state
  end

  defp add_prev_state(%__MODULE__{prev_states: prev_states} = state, height, prev_state),
    do: %__MODULE__{state | prev_states: [{height - 1, prev_state} | prev_states]}

  @spec invalidate(t(), height()) :: t()
  @doc """
  Invalidation simply picks the last valid state from the list of prev_states.
  """
  def invalidate(%__MODULE__{prev_states: prev_states}, height) do
    [new_state | _rest] =
      Enum.drop_while(prev_states, fn {state_height, _state} -> state_height >= height end)

    new_state
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
