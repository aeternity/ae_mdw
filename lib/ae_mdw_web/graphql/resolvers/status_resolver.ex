defmodule AeMdwWeb.GraphQL.Resolvers.StatusResolver do
  alias AeMdw.Db.Status

  def status(_p, _args, %{context: %{state: state}}) do
    node_status = Status.node_and_mdw_status(state)
    partial = !!node_status[:mdw_syncing]
    {:ok, Map.put(node_status, :partial, partial)}
  end

  def status(_p, _args, _res), do: {:error, "partial_state_unavailable"}

  def sync_status(_p, _args, %{context: %{state: state}}) do
    try do
      node_status = Status.node_and_mdw_status(state)
      partial = !!node_status[:mdw_syncing]
      {:ok, %{last_synced_height: node_status[:mdw_height], partial: partial}}
    rescue
      _ -> {:error, "partial_state_unavailable"}
    end
  end

  def sync_status(_p, _args, _res), do: {:error, "partial_state_unavailable"}
end
