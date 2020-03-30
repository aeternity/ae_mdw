defmodule AeMdwWeb.GCWorker do
  use GenServer

  alias AeMdwWeb.EtsManager

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    gc_time = Application.get_env(:ae_mdw, __MODULE__)[:gc_time]
    new_state = %{gc_time: gc_time}
    Process.send_after(__MODULE__, :clean, gc_time)
    {:ok, new_state}
  end

  def handle_info(:clean, %{gc_time: gc_time} = state) do
    EtsManager.delete_old_records(gc_time)

    Process.send_after(__MODULE__, :clean, gc_time)
    {:noreply, state}
  end
end
