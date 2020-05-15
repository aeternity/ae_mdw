defmodule AeMdwWeb.Websocket.Supervisor do
  use Supervisor

  alias AeMdwWeb.Websocket.EtsManager, as: Ets

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    config = Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)
    Ets.init(config[:main])
    Ets.init(config[:sub])
    Ets.init(config[:subs_channel_targets])
    Ets.init(config[:subs_target_channels])

    children = [AeMdwWeb.Listener]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
