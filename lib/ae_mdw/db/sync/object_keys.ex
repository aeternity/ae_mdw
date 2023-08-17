defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts active and inactive names and oracles deduplicating on memory and persisted keys.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log

  import AeMdw.Util, only: [max_name_bin: 0, max_256bit_bin: 0]
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

  @name_halves [
    {"", "g" <> max_name_bin()},
    {"h", max_name_bin()}
  ]

  @oracle_halves [
    {<<0::256>>, <<trunc(:math.pow(2, 31))::256>>},
    {<<trunc(:math.pow(2, 31)) + 1::256>>, max_256bit_bin()}
  ]

  @opts [:named_table, :set, :public]
  @init_timeout 300_000

  @spec init(State.t()) :: :ok
  def init(state) do
    _tid1 = :ets.new(@active_names_table, @opts)
    _tid2 = :ets.new(@inactive_names_table, @opts)
    _tid3 = :ets.new(@active_oracles_table, @opts)
    _tid4 = :ets.new(@inactive_oracles_table, @opts)

    {ts, :ok} =
      :timer.tc(fn ->
        :ok = load_tables(state, @name_halves, @active_names_table, @inactive_names_table)
        :ok = load_tables(state, @oracle_halves, @active_oracles_table, @inactive_oracles_table)
      end)

    Log.info("Loaded object keys in #{div(ts, 1_000_000)} secs")

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
      |> list_mem_keys(table)
      |> Enum.count(&(not :ets.member(table, &1)))

    commited_keys = :ets.info(table, :size)

    memory_only_keys + commited_keys
  end

  defp list_mem_keys(state, table) do
    model_table = @store_tables[table]

    if State.has_memory_store?(state) do
      state
      |> State.without_fallback()
      |> stream_all_keys(model_table)
    else
      []
    end
  end

  defp stream_all_keys(state, table), do: Collection.stream(state, table, nil)

  defp load_tables(state, key_boundaries, active_table, inactive_table) do
    true =
      key_boundaries
      |> Enum.flat_map(
        &[
          Task.async(fn -> load_records(state, active_table, &1) end),
          Task.async(fn -> load_records(state, inactive_table, &1) end)
        ]
      )
      |> Task.await_many(@init_timeout)
      |> Enum.all?(&(&1 == :ok))

    :ok
  end

  defp load_records(state, table, key_boundary) do
    records =
      state
      |> Collection.stream(@store_tables[table], key_boundary)
      |> Enum.map(&{&1})

    :ets.insert(table, records)
    :ok
  end
end
