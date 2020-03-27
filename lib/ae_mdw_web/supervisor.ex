defmodule AeMdwWeb.Supervisor do
  use Supervisor

  def start_link(args), do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    table_name = Application.get_env(:ae_mdw, AeMdwWeb.GCWorker)[:table_name]
    :ets.new(table_name, [:named_table, :public])

    children = [AeMdwWeb.Endpoint, AeMdwWeb.GCWorker]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
