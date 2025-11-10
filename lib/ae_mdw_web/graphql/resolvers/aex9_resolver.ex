defmodule AeMdwWeb.GraphQL.Resolvers.Aex9Resolver do
  alias AeMdw.AexnTokens
  alias AeMdw.Aex9
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  require Model

  def aex9_count(_p, _args, %{context: %{state: state}}) do
    count =
      case State.get(state, Model.Stat, Stats.aexn_count_key(:aex9)) do
        {:ok, Model.stat(payload: count)} -> count
        :not_found -> 0
      end

    {:ok, count}
  end

  def aex9_contracts(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query = %{}
    query = Helpers.maybe_put(query, "prefix", Map.get(args, :prefix))
    query = Helpers.maybe_put(query, "exact", Map.get(args, :exact))

    AexnTokens.fetch_contracts(state, pagination, :aex9, query, order_by, cursor, true)
    |> Helpers.make_page()
  end

  def aex9_contract(_p, %{id: id}, %{context: %{state: state}}) do
    AexnTokens.fetch_contract(state, :aex9, id, true) |> Helpers.make_single()
  end

  def aex9_contract_balances(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query =
      case Map.get(args, :block_hash) do
        nil -> %{}
        bh -> %{"block_hash" => bh}
      end

    Aex9.fetch_event_balances(state, id, pagination, cursor, order_by, query)
    |> Helpers.make_page()
  end

  def aex9_balance_history(_p, %{contract_id: cid, account_id: aid} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    with {:ok, contract_pk} <- AeMdw.Validate.id(cid, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]) do
      Aex9.fetch_balance_history(state, contract_pk, account_pk, scope, cursor, pagination)
      |> Helpers.make_page()
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end
end
