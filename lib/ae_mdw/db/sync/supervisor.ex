defmodule AeMdw.Db.Sync.Supervisor do
  use Supervisor

  alias AeMdw.EtsCache
  alias AeMdw.Db.Sync.Name.Cache, as: NC

  # 3 days
  @name_last_tx_cache_cleanup_minutes 4320

  ##########

  def start_link(),
    do: start_link([])

  def start_link(args),
    do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    EtsCache.new(:last_name_claim, @name_last_tx_cache_cleanup_minutes)
    EtsCache.new(:last_name_update, @name_last_tx_cache_cleanup_minutes)

    children = [
      AeMdw.Db.Sync,
      AeMdw.Db.Sync.ForkDetector
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
