defmodule AeMdw.Db.State do
  @moduledoc """
  Represents the overall state of the database, regardless of where it is being
  stored. This state can be updated in any way, but it's supposed to be done immutably -
  every change in the state returns a new one.
  """

  alias AeMdw.Database
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.Mutation

  defstruct [:txn, :stats, :cache]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep direction() :: Database.direction()
  @typep table() :: Database.table()
  @typep stat_name() :: atom()
  @typep stats() :: %{atom() => non_neg_integer()}
  @typep cache_name() :: atom()

  @opaque t() :: %__MODULE__{
            txn: Database.transaction() | nil,
            stats: stats(),
            cache: %{cache_name() => map()}
          }

  @spec new() :: t()
  def new do
    %__MODULE__{stats: %{}, cache: %{}}
  end

  @spec commit(t(), [Mutation.t()]) :: t()
  def commit(state, mutations) do
    {:ok, txn} = RocksDb.transaction_new()
    state2 = %__MODULE__{state | txn: txn}

    new_state =
      mutations
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(state2, &Mutation.execute/2)

    :ok = RocksDb.transaction_commit(txn)

    %__MODULE__{new_state | txn: nil}
  end

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{txn: txn} = state, tab, record) do
    Database.write(txn, tab, record)

    state
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{txn: txn}, table, key) do
    Database.dirty_fetch(txn, table, key)
  end

  @spec fetch!(t(), table(), key()) :: record() | :not_found
  def fetch!(state, table, key) do
    case get(state, table, key) do
      {:ok, record} -> record
      :not_found -> raise "#{inspect(key)} not found"
    end
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(_state, table) do
    Database.count_keys(table)
  end

  @spec exists?(t(), table(), key()) :: boolean()
  def exists?(_state, table, key) do
    Database.exists?(table, key)
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{txn: txn} = state, tab, key) do
    Database.delete(txn, tab, key)

    state
  end

  @spec next(t(), table(), key()) :: {:ok, key()} | :none
  def next(%__MODULE__{txn: txn}, table, key), do: Database.dirty_next(txn, table, key)

  @spec next(t(), table(), direction(), key()) :: {:ok, key()} | :none
  def next(_state, tab, direction, cursor), do: Database.next_key(tab, direction, cursor)

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
