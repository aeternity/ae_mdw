defmodule AeMdwWeb.Supervisor do
  use Supervisor

  alias AeMdw.Blocks

  @spec start_link([]) :: {:ok, pid()}
  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    Blocks.create_cache_table()
    children = [AeMdwWeb.Endpoint]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
