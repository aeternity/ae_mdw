defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts active and inactive names and oracles deduplicating on memory and persisted keys.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  # commited keys
  @active_names_table :db_active_names
  @active_oracles_table :db_active_oracles
  @inactive_names_table :db_inactive_names
  @inactive_oracles_table :db_inactive_oracles

  @store_tables %{
    @active_names_table => Model.ActiveName,
    @inactive_names_table => Model.InactiveName,
    @active_oracles_table => Model.ActiveOracle,
    @inactive_oracles_table => Model.InactiveOracle
  }

  @opts [:named_table, :set, :public]
  @init_timeout 300_000

  @spec init(State.t()) :: :ok
  def init(state) do
    _tid1 = :ets.new(@active_names_table, @opts)
    _tid2 = :ets.new(@inactive_names_table, @opts)
    _tid3 = :ets.new(@active_oracles_table, @opts)
    _tid4 = :ets.new(@inactive_oracles_table, @opts)

    {ts, _} =
      :timer.tc(fn ->
        [
          Task.async(fn ->
            :ets.insert(@active_names_table, all_records(state, Model.ActiveName))
          end),
          Task.async(fn ->
            :ets.insert(@inactive_names_table, all_records(state, Model.InactiveName))
          end),
          Task.async(fn ->
            :ets.insert(@active_oracles_table, all_records(state, Model.ActiveOracle))
          end),
          Task.async(fn ->
            :ets.insert(@inactive_oracles_table, all_records(state, Model.InactiveOracle))
          end)
        ]
        |> Task.await_many(@init_timeout)
      end)

    Log.info("Loaded object keys in #{div(ts, 1_000)}ms")

    :ok
  end

  @spec put_active_name(State.t(), String.t()) :: :ok
  def put_active_name(state, name) do
    if not State.has_memory_store?(state) do
      put(@active_names_table, name)
      del(@inactive_names_table, name)
    end

    :ok
  end

  @spec put_inactive_name(State.t(), String.t()) :: :ok
  def put_inactive_name(state, name) do
    if not State.has_memory_store?(state) do
      put(@inactive_names_table, name)
      del(@active_names_table, name)
    end

    :ok
  end

  @spec put_active_oracle(State.t(), pubkey()) :: :ok
  def put_active_oracle(state, oracle) do
    if not State.has_memory_store?(state) do
      put(@active_oracles_table, oracle)
      del(@inactive_oracles_table, oracle)
    end

    :ok
  end

  @spec put_inactive_oracle(State.t(), pubkey()) :: :ok
  def put_inactive_oracle(state, oracle) do
    if not State.has_memory_store?(state) do
      put(@inactive_oracles_table, oracle)
      del(@active_oracles_table, oracle)
    end

    :ok
  end

  @spec count_active_names(State.t()) :: non_neg_integer()
  def count_active_names(state), do: count(state, @active_names_table)

  @spec count_inactive_names(State.t()) :: non_neg_integer()
  def count_inactive_names(state), do: count(state, @inactive_names_table)

  @spec count_active_oracles(State.t()) :: non_neg_integer()
  def count_active_oracles(state), do: count(state, @active_oracles_table)

  @spec count_inactive_oracles(State.t()) :: non_neg_integer()
  def count_inactive_oracles(state), do: count(state, @inactive_oracles_table)

  defp put(table, key) do
    :ets.insert(table, {key})
  end

  defp del(table, key) do
    :ets.delete(table, key)
  end

  defp count(state, table) do
    memory_only_keys =
      state
      |> list_keys(table)
      |> Enum.count(&(not :ets.member(table, &1)))

    commited_keys = :ets.info(table, :size)

    memory_only_keys + commited_keys
  end

  defp list_keys(state, table) do
    model_table = @store_tables[table]

    if State.has_memory_store?(state) do
      state
      |> State.without_fallback()
      |> stream_all_keys(model_table)
    else
      stream_all_keys(state, model_table)
    end
  end

  defp stream_all_keys(state, table), do: Collection.stream(state, table, nil)

  defp all_records(state, table), do: state |> stream_all_keys(table) |> Enum.map(&{&1})
end
