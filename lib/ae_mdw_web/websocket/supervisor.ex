defmodule AeMdwWeb.Websocket.Supervisor do
  use Supervisor

  def start_link(arg),
    do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(arg) do
    :ets.new(:subs_pids, [:public, :ordered_set, :named_table])
    :ets.new(:subs_main, [:public, :ordered_set, :named_table])
    :ets.new(:subs_channel_targets, [:public, :ordered_set, :named_table])
    :ets.new(:subs_target_channels, [:public, :ordered_set, :named_table])

    children = [
      {AeMdwWeb.Websocket.Listener, arg},
      {Riverside, [handler: AeWebsocket.Websocket.SocketHandler]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
