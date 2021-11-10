defmodule AeMdwWeb.Supervisor do
  use Supervisor

  alias AeMdw.EtsCache
  alias AeMdw.Blocks

  @spec start_link([]) :: {:ok, pid()}
  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    config = Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)
    continuation_exp = config[:continuation_cache_expiration_minutes]
    EtsCache.new(AeMdwWeb.Continuation.table(), continuation_exp, :ordered_set)
    Blocks.create_cache_table()
    children = [AeMdwWeb.Endpoint]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
