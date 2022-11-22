defmodule AeMdwWeb.Websocket.Supervisor do
  use Supervisor

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    AeMdwWeb.Websocket.Subscriptions.init_tables()

    children = [
      AeMdwWeb.Websocket.Broadcaster,
      AeMdwWeb.Websocket.ChainListener,
      AeMdwWeb.Websocket.Subscriptions
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
