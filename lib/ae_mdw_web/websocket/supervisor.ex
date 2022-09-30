defmodule AeMdwWeb.Websocket.Supervisor do
  use Supervisor

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    :subs_pids = :ets.new(:subs_pids, [:public, :ordered_set, :named_table])
    :subs_main = :ets.new(:subs_main, [:public, :ordered_set, :named_table])
    :subs_channel_targets = :ets.new(:subs_channel_targets, [:public, :ordered_set, :named_table])
    :subs_target_channels = :ets.new(:subs_target_channels, [:public, :ordered_set, :named_table])

    children = [
      AeMdwWeb.Websocket.Broadcaster,
      AeMdwWeb.Websocket.ChainListener,
      {Riverside, [handler: AeWebsocket.Websocket.SocketHandler]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
