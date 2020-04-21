defmodule AeMdwWeb.Supervisor do
  use Supervisor

  alias AeMdw.EtsCache
  alias AeMdwWeb.Continuation
  alias AeMdwWeb.Contract

  def start_link([]),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    config = Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)
    EtsCache.init(Continuation.table(), config[:continuation_cache_expiration_minutes])
    EtsCache.init(Contract.table(), config[:contract_cache_expiration_minutes])

    children = [AeMdwWeb.Endpoint]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
