defmodule AeMdwWeb.GraphQL.Resolvers.Aex141Resolver do
  alias AeMdw.AexnTokens
  alias AeMdw.AexnTransfers
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  def aex141_count(_p, _args, %{context: %{state: state}}) do
    count =
      case State.get(state, Model.Stat, Stats.aexn_count_key(:aex141)) do
        {:ok, Model.stat(payload: count)} -> count
        :not_found -> 0
      end

    {:ok, count}
  end

  def aex141_contracts(_p, args, %{context: %{state: state}}) do
    order_by = Map.get(args, :order_by)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "prefix", Map.get(args, :prefix))
    query = Helpers.maybe_put(query, "exact", Map.get(args, :exact))

    AexnTokens.fetch_contracts(state, pagination, :aex141, query, order_by, cursor, true)
    |> Helpers.make_page()
  end

  def aex141_contract(_p, %{id: id}, %{context: %{state: state}}) do
    AexnTokens.fetch_contract(state, :aex141, id, true) |> Helpers.make_single()
  end

  def aex141_transfers(_p, args, %{context: %{state: %State{} = state}}) do
    sender = Map.get(args, :sender)
    recipient = Map.get(args, :recipient)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "from", sender)
    query = Helpers.maybe_put(query, "to", recipient)

    # TODO: can this be refactored using Helpers.make_page/1 ?
    case AexnTransfers.fetch_aex141_transfers(state, pagination, cursor, query) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: Enum.map(items, &AeMdwWeb.AexnView.pair_transfer_to_map(state, &1))
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end
end
