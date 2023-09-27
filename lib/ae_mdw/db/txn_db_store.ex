defmodule AeMdw.Db.TxnDbStore do
  @moduledoc """
  Store implementation with operations accessing the Database through an open
  transaction.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model

  require Model

  @derive AeMdw.Db.Store
  defstruct [:txn]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @opaque t() :: %__MODULE__{
            txn: Database.transaction()
          }

  @spec transaction((t() -> term())) :: term()
  def transaction(fun) do
    txn = Database.transaction_new()

    result = fun.(%__MODULE__{txn: txn})

    Database.transaction_commit(txn)

    result
  end

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{txn: txn} = store, table, record) do
    Database.write(txn, table, record)

    store
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  # Temp fix for old names format
  def get(%__MODULE__{txn: txn}, table, key)
      when table in [Model.ActiveName, Model.InactiveName] do
    case Database.dirty_fetch(txn, table, key) do
      {:ok, {:name, plain_name, active, expire, revoke, auction_timeout, owner, _previous}} ->
        {:ok,
         Model.name(
           index: plain_name,
           active: active,
           expire: expire,
           revoke: revoke,
           auction_timeout: auction_timeout,
           owner: owner
         )}

      other ->
        other
    end
  end

  def get(%__MODULE__{txn: txn}, table, key), do: Database.dirty_fetch(txn, table, key)

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{txn: txn} = store, table, key) do
    Database.delete(txn, table, key)

    store
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(%__MODULE__{txn: txn}, table, key), do: Database.dirty_next(txn, table, key)

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(%__MODULE__{txn: txn}, table, key), do: Database.dirty_prev(txn, table, key)

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(%__MODULE__{txn: txn}, table), do: Database.dirty_count(txn, table)
end
