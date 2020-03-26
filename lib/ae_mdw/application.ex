defmodule AeMdw.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias AeMdw.Db.Model

  use Application

  def start(_type, _args) do
    init(:meta)

    children = [
      AeMdw.Db.Sync.Supervisor,
      AeMdwWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  def init(:meta) do
    alias AeMdw.Extract

    {:ok, type_mod_map} = Extract.tx_map()
    type_mod_mapper = &Map.fetch!(type_mod_map, &1)

    {tx_fields, tx_ids} =
      Enum.reduce(type_mod_map, {%{}, %{}}, fn {type, _}, {tx_fields, tx_ids} ->
        {:ok, fields, ids} = Extract.tx_record_info(type, type_mod_mapper)
        {put_in(tx_fields[type], fields), put_in(tx_ids[type], ids)}
      end)

    SmartGlobal.new(
      AeMdw.Node,
      %{
        tx_mod: type_mod_map,
        tx_types: [{[], Map.keys(type_mod_map)}],
        tx_fields: tx_fields,
        tx_ids: tx_ids
      }
    )
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  def config_change(changed, _new, removed) do
    AeMdwWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
