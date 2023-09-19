defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts active and inactive names and oracles.

  Persisted initial keys are loaded by staged parallel tasks for faster loading.

  It deduplicates new on memory compared with persisted keys and the counting itself
  is performed in constant time by table sizes.
  """

  use GenStateMachine

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.Server, as: SyncServer
  alias AeMdw.Log

  import AeMdw.Util, only: [max_name_bin: 0, max_256bit_bin: 0]

  require Logger

  defstruct start_datetime: nil, tasks: MapSet.new()

  @typep state() :: :waiting | :loading_names | :loading_oracles | :finished
  @typep state_data() :: %__MODULE__{}
  @typep cast_event() :: :start_loading
  @typep reason() :: term()
  @typep info_event() :: {reference(), :ok} | {:DOWN, reference(), :process, pid(), reason()}
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

  @spec start_link(GenServer.options()) :: :gen_statem.start_ret()
  def start_link(_opts), do: GenStateMachine.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  @spec init(:ok) :: :gen_statem.init_result(state())
  def init(:ok) do
    _tid1 = :ets.new(@active_names_table, @opts)
    _tid2 = :ets.new(@inactive_names_table, @opts)
    _tid3 = :ets.new(@active_oracles_table, @opts)
    _tid4 = :ets.new(@inactive_oracles_table, @opts)

    {:ok, :waiting, %__MODULE__{}}
  end

  @spec start() :: :ok
  def start do
    GenStateMachine.cast(__MODULE__, :start_loading)
  end

  @impl true
  @spec handle_event(:cast, cast_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  @spec handle_event(:info, info_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  def handle_event(:cast, :start_loading, :waiting, state_data) do
    tasks =
      @name_halves
      |> load_tables_tasks(@active_names_table, @inactive_names_table)
      |> MapSet.new(fn task -> task.ref end)

    {:next_state, :loading_names,
     %{state_data | tasks: tasks, start_datetime: NaiveDateTime.utc_now()}}
  end

  def handle_event(:info, {ref, :ok}, :loading_names, %{tasks: tasks} = state_data) do
    Process.demonitor(ref, [:flush])
    tasks = MapSet.delete(tasks, ref)

    if MapSet.size(tasks) == 0 do
      tasks =
        @oracle_halves
        |> load_tables_tasks(@active_oracles_table, @inactive_oracles_table)
        |> MapSet.new(fn task -> task.ref end)

      {:next_state, :loading_oracles, %{state_data | tasks: tasks}}
    else
      {:keep_state, %{state_data | tasks: tasks}}
    end
  end

  def handle_event(
        :info,
        {ref, :ok},
        :loading_oracles,
        %{tasks: tasks, start_datetime: start_datetime} = state_data
      ) do
    Process.demonitor(ref, [:flush])
    tasks = MapSet.delete(tasks, ref)

    if MapSet.size(tasks) == 0 do
      duration = NaiveDateTime.diff(NaiveDateTime.utc_now(), start_datetime, :second)
      Log.info("Loaded object keys in #{duration} secs")

      SyncServer.start_sync()

      {:next_state, :finished, %{state_data | tasks: MapSet.new()}, :hibernate}
    else
      {:keep_state, %{state_data | tasks: tasks}}
    end
  end

  def handle_event(:info, {:DOWN, _ref, :process, _pid, _reason}, _state, state_data) do
    GenStateMachine.stop(__MODULE__, :shutdown)
    {:keep_state, state_data}
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

  defp load_tables_tasks(key_boundaries, active_table, inactive_table) do
    state = State.new()

    key_boundaries
    |> Enum.flat_map(&[{active_table, &1}, {inactive_table, &1}])
    |> Enum.map(fn {table, key_boundary} ->
      Task.Supervisor.async_nolink(SyncServer.task_supervisor(), fn ->
        load_records(state, table, key_boundary)
      end)
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
