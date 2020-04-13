defmodule AeMdwWeb.Supervisor do
  use Supervisor

  alias AeMdwWeb.Continuation

  @default_cont_expiration_minutes 30

  def start_link(args),
    do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    gc_time = cont_expiration_msecs()

    :ets.new(Continuation.table(), [
          :named_table,
          :public,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])

    {:ok, _} = :timer.apply_interval(gc_time, Continuation, :purge, [gc_time])

    children = [AeMdwWeb.Endpoint]
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp cont_expiration_msecs() do
    endpoint_config = Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)
    minutes = endpoint_config[:cont_expiration_minutes] || @default_cont_expiration_minutes
    :timer.minutes(minutes)
  end

end
