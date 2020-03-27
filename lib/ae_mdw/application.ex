defmodule AeMdw.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias AeMdw.Db.Model

  use Application

  def start(_type, _args) do
    init(:meta)

    children = [AeMdwWeb.Supervisor]

    opts = [strategy: :one_for_one, name: AeMdw.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init(:meta) do
    {:ok, type_mod_map} = AeMdw.Extract.tx_map()
    Model.set_meta(:tx_types, Map.keys(type_mod_map))

    for {type, mod} <- type_mod_map,
        do: Model.set_meta({:tx_mod, type}, mod)

    for {type, _mod} <- type_mod_map do
      {:ok, fields, ids} = AeMdw.Extract.tx_record_info(type)
      Model.set_meta({:tx_fields, type}, fields)
      Model.set_meta({:tx_ids, type}, ids)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AeMdwWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
