defmodule AeMdwWeb.Supervisor do
  use Supervisor

  @spec start_link([]) :: {:ok, pid()}
  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    children = [
      AeMdwWeb.Endpoint,
      AeMdwWeb.WebsocketEndpoint
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
