defmodule AeMdw.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias AeMdw.Db.Model

  import AeMdw.Util

  use Application

  def start(_type, _args) do
    init(:meta)

    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      AeMdwWeb.Endpoint
      # Starts a worker by calling: AeMdw.Worker.start_link(arg)
      # {AeMdw.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AeMdw.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init(:meta) do
    tx_types = ok!(AeMdw.Extract.tx_types())
    Model.set_meta(:tx_types, tx_types)

    for {type, mod} <- ok!(AeMdw.Extract.tx_map()),
        do: Model.set_meta({:tx_mod, type}, mod)

    for type <- tx_types,
        do: Model.set_meta({:tx_obj, type}, ok!(AeMdw.Extract.tx_getters(type)))

    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AeMdwWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
