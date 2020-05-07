defmodule AeMdwWeb.Websocket.Supervisor do
  use Supervisor

  alias AeMdwWeb.Websocket.EtsManager, as: Ets

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    Ets.init_duplicate_bag(:subs_channel_targets)
    Ets.init_duplicate_bag(:subs_target_channels)
    Ets.init_ordered(:main)

    children = [AeMdwWeb.Listener]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
