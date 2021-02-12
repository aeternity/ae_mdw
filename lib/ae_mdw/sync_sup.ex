defmodule AeMdw.Sync.Supervisor do
  use DynamicSupervisor

  ##########

  def start_link(args),
    do: DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    :ets.new(:name_sync_cache, [:named_table, :ordered_set, :public])
    :ets.new(:oracle_sync_cache, [:named_table, :ordered_set, :public])
    DynamicSupervisor.init(max_restarts: 0, max_children: 1, strategy: :one_for_one)
  end


  def sync(true),
    do: DynamicSupervisor.start_child(__MODULE__, AeMdw.Db.Sync.Supervisor)

  def sync(false) do
    case DynamicSupervisor.which_children(__MODULE__) do
      [{:undefined, pid, _, _}] when is_pid(pid) ->
        case DynamicSupervisor.terminate_child(__MODULE__, pid) do
          :ok -> :ok
          {:error, :not_found} -> sync(false)
        end
      [{:undefined, :restarting, _, _}] ->
        Process.sleep(100)
        sync(false)
      [] ->
        :ok
    end
  end

end
