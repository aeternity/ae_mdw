defmodule AeMdwWeb.GraphQL.Resolvers.TransactionResolver do
  alias AeMdw.Txs
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State

  def transaction(_p, %{hash: hash}, %{context: %{state: state}}) do
    with {:ok, tx_hash} <- Validate.id(hash) do
      Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true)
      |> Helpers.make_single()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  def pending_transactions(_p, args, _res) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    try do
      NodeStore.new()
      |> State.new()
      |> Txs.fetch_pending_txs(pagination, nil, cursor)
      |> Helpers.make_page()
    rescue
      _ -> {:error, "pending_transactions_error"}
    end
  end

  def pending_transactions_count(_p, _args, _res) do
    try do
      {:ok, AeMdw.Node.Db.pending_txs_count()}
    rescue
      _ -> {:error, "pending_transactions_count_error"}
    end
  end
end
