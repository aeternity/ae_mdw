defmodule AeMdw.Db.State do
  @moduledoc """
  Represents the overall state of the database, regardless of where it is being
  stored.
  """
  alias AeMdw.Database
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.TxnMutation

  defstruct [:tables, :queued_changes]

  use GenServer

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  # @typep row() :: {:active, record()} | :deleted
  @typep table() :: Database.table()
  @typep records() :: :gb_trees.tree()
  @typep tables() :: %{Database.table() => records()}
  @opaque t() :: %__MODULE__{tables: tables()}

  @spec commit(t(), [TxnMutation.t()]) :: t()
  def commit(state, mutations) do
    state = Enum.reduce(mutations, state, &TxnMutation.execute/2)

    queue_changes(state)

    state
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{tables: tables}, table, key) do
    records = Map.get(tables, table, [])

    case :gb_trees.lookup(key, records) do
      {:value, {:active, record}} ->
        {:ok, record}

      {:value, :deleted} ->
        :not_found

      :none ->
        case Database.read(table, key) do
          [record] -> {:ok, record}
          [] -> :not_found
        end
    end
  end

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{tables: tables} = state, table, record) do
    key = elem(record, 1)

    new_tables =
      Map.update(tables, table, :gb_trees.empty(), fn
        records -> :gb_trees.insert(key, {:active, record}, records)
      end)

    %__MODULE__{state | tables: new_tables}
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{tables: tables} = state, table, key) do
    new_tables =
      Map.update(tables, table, :gb_trees.empty(), fn
        records -> :gb_trees.delete(records, key)
      end)

    %__MODULE__{state | tables: new_tables}
  end

  ## Gen Server calls
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec current_state :: t()
  def current_state do
    GenServer.call(__MODULE__, :current_state)
  end

  defp queue_changes(%__MODULE__{tables: tables}) do
    GenServer.cast(__MODULE__, {:queue_changes, tables})
  end

  ## Gen Server Callbacks

  @impl true
  def init(:ok) do
    {:ok, %__MODULE__{queued_changes: :queue.new()}}
  end

  @impl true
  def handle_call(:current_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:queue_changes, tables}, state) do
    # this call would queue the changes to be performed once a certain condition is
    # reached (e.g. once another queue for changes is added)

    # committing the changes would be something along these lines:
    transaction = RocksDb.transaction_new()

    Enum.each(tables, fn {table, records} ->
      Enum.each(records, fn
        {_key, {:active, record}} -> Database.write(transaction, table, record)
        {_key, :deleted} -> :ok
      end)
    end)

    RocksDb.transaction_commit(transaction)

    {:noreply, state}
  end
end
