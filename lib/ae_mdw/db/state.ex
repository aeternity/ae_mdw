defmodule AeMdw.Db.State do
  @moduledoc """
  Represents the overall state of the database, regardless of where it is being
  stored. This state can be updated in any way, but it's supposed to be done immutably -
  every change in the state returns a new one.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.AsyncStoreMutation
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Store
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Sync.AsyncTasks.Consumer
  alias AeMdw.Sync.AsyncTasks.Producer

  defstruct [:store, :stats, :cache, :jobs]

  @type key() :: Database.key()
  @type record() :: Database.record()
  @type direction() :: Database.direction()
  @type table() :: Database.table()
  @typep stat_name() :: atom()
  @typep cache_name() :: atom()
  @typep height() :: Blocks.height()
  @typep job_type() :: Consumer.task_type()

  @opaque t() :: %__MODULE__{
            store: Store.t(),
            stats: %{stat_name() => non_neg_integer()},
            cache: %{cache_name() => map()},
            jobs: %{{job_type(), list()} => list()}
          }

  @state_pm_key :global_state

  @spec new(Store.t()) :: t()
  def new(store \\ DbStore.new()),
    do: %__MODULE__{store: store, stats: %{}, cache: %{}, jobs: %{}}

  @spec height(t()) :: height()
  def height(state), do: DbUtil.synced_height(state)

  @spec commit(t(), [Mutation.t()], boolean()) :: t()
  def commit(%__MODULE__{store: prev_store} = state, mutations, clear_mem? \\ false) do
    new_state =
      %__MODULE__{jobs: jobs} =
      TxnDbStore.transaction(fn store ->
        state2 = %__MODULE__{state | store: store}

        [mutations, AsyncStoreMutation.new()]
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(state2, &Mutation.execute/2)
      end)

    enqueue_jobs(jobs, only_new: true)

    if clear_mem? do
      :persistent_term.erase(@state_pm_key)
    end

    %__MODULE__{new_state | store: prev_store, jobs: %{}}
  end

  @spec commit_db(t(), [Mutation.t()], boolean()) :: t()
  def commit_db(state, mutations, clear_mem? \\ true) do
    state2 = commit(state, mutations, clear_mem?)

    Producer.save_enqueued()

    state2
  end

  @spec commit_mem(t(), [Mutation.t()]) :: t()
  def commit_mem(state, mutations) do
    state2 =
      %__MODULE__{jobs: jobs} =
      mutations
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(state, &Mutation.execute/2)

    enqueue_jobs(jobs, only_new: false)

    :persistent_term.put(@state_pm_key, state2)

    %__MODULE__{state2 | jobs: %{}}
  end

  @spec mem_state() :: t()
  def mem_state do
    case :persistent_term.get(@state_pm_key, :none) do
      :none -> new_mem_state()
      state -> state
    end
  end

  @spec new_mem_state() :: t()
  def new_mem_state, do: new(MemStore.new(DbStore.new()))

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

  @spec update(t(), table(), key(), (record() -> record()), term() | nil) :: t()
  def update(state, table, key, update_fn, default \\ nil) do
    case get(state, table, key) do
      {:ok, record} -> put(state, table, update_fn.(record))
      :not_found -> put(state, table, update_fn.(default))
    end
  end

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

  @spec clear_cache(t()) :: t()
  def clear_cache(state), do: %__MODULE__{state | cache: %{}}

  @spec enqueue(t(), job_type(), list(), list()) :: t()
  def enqueue(%__MODULE__{jobs: jobs} = state, task_type, dedup_args, extra_args \\ []) do
    %__MODULE__{state | jobs: Map.put(jobs, {task_type, dedup_args}, extra_args)}
  end

  defp enqueue_jobs(jobs, opts) do
    Enum.each(jobs, fn {{job_type, dedup_args}, extra_args} ->
      Producer.enqueue(job_type, dedup_args, extra_args, opts)
    end)
  end
end
