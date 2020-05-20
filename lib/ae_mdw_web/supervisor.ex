defmodule AeMdwWeb.Supervisor do
  use Supervisor

  alias AeMdw.EtsCache

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    config = Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)
    continuation_exp = config[:continuation_cache_expiration_minutes]
    EtsCache.new(AeMdwWeb.Continuation.table(), continuation_exp, :ordered_set)

    children = [AeMdwWeb.Endpoint]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
