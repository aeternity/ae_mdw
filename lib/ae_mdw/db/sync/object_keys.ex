defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts active and inactive names and oracles.

  Persisted initial keys are loaded by staged parallel tasks for faster loading.

  It deduplicates new on memory compared with persisted keys and the counting itself
  is performed in constant time by table sizes.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Sync.SyncingQueue

  import AeMdw.Util, only: [max_name_bin: 0, max_256bit_bin: 0, max_int: 0]

  require Logger
  require Model

  @typep pubkey :: Db.pubkey()

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
    {<<0::256>>, <<trunc(:math.pow(2, 128))::256>>},
    {<<trunc(:math.pow(2, 128)) + 1::256>>, max_256bit_bin()}
  ]

  @opts [:named_table, :set, :public]

  @spec load() :: :ok
  def load do
    _tid1 = :ets.new(@active_names_table, @opts)
    _tid2 = :ets.new(@inactive_names_table, @opts)
    _tid3 = :ets.new(@active_oracles_table, @opts)
    _tid4 = :ets.new(@inactive_oracles_table, @opts)

    [
      load_tables_fns(@oracle_halves, @active_oracles_table, @inactive_oracles_table),
      load_tables_fns(@name_halves, @active_names_table, @inactive_names_table)
    ]
    |> List.flatten()
    |> Enum.each(&SyncingQueue.push/1)
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

  @spec count_contracts(State.t()) :: non_neg_integer()
  def count_contracts(state) do
    memory_only_keys =
      state
      |> list_mem_keys(Model.Origin)
      |> Enum.count()

    memory_only_keys + db_contracts_count()
  end

  defp put(table, key) do
    :ets.insert(table, {key})
  end

  defp del(table, key) do
    :ets.delete(table, key)
  end

  defp count(state, table) do
    model_table = @store_tables[table]

    memory_only_keys =
      state
      |> list_mem_keys(model_table)
      |> Enum.count(&(not :ets.member(table, &1)))

    commited_keys = :ets.info(table, :size)

    memory_only_keys + commited_keys
  end

  defp db_contracts_count() do
    db_state = State.new()

    case State.prev(db_state, Model.TotalStat, nil) do
      {:ok, last_gen} ->
        m_total_stat = State.fetch!(db_state, Model.TotalStat, last_gen)

        Model.total_stat(m_total_stat, :contracts)

      :none ->
        0
    end
  end

  defp list_mem_keys(state, table) do
    if State.has_memory_store?(state) do
      state
      |> State.without_fallback()
      |> stream_all_keys(table)
    else
      []
    end
  end

  defp stream_all_keys(state, Model.Origin) do
    [:contract_create_tx, :contract_call_tx, :ga_attach_tx]
    |> Enum.map(fn tx_type ->
      key_boundary = {{tx_type, <<>>, 0}, {tx_type, max_256bit_bin(), max_int()}}
      Collection.stream(state, Model.Origin, :forward, key_boundary, nil)
    end)
    |> Collection.merge(:forward)
    |> Stream.map(fn {_type, pubkey, _txi} -> pubkey end)
  end

  defp stream_all_keys(state, table), do: Collection.stream(state, table, nil)

  defp load_tables_fns(key_boundaries, active_table, inactive_table) do
    state = State.new()

    key_boundaries
    |> Enum.flat_map(&[{active_table, &1}, {inactive_table, &1}])
    |> Enum.map(fn {table, key_boundary} ->
      fn -> load_records(state, table, key_boundary) end
    end)
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
