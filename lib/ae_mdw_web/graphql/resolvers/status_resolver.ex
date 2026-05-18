defmodule AeMdwWeb.GraphQL.Resolvers.StatusResolver do
  alias AeMdw.Db.Status

  @spec status(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def status(_parent, _args, %{context: %{state: state}}) do
    node_status = Status.node_and_mdw_status(state)
    partial = !!node_status[:mdw_syncing]
    {:ok, Map.put(node_status, :partial, partial)}
  end

  def status(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec sync_status(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def sync_status(_parent, _args, %{context: %{state: state}}) do
    try do
      node_status = Status.node_and_mdw_status(state)
      partial = !!node_status[:mdw_syncing]
      {:ok, %{last_synced_height: node_status[:mdw_height], partial: partial}}
    rescue
      _error ->
        require Logger
        Logger.warning("sync_status failed to read node status")
        {:error, "partial_state_unavailable"}
    end
  end

  def sync_status(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}
end
