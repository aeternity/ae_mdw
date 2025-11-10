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
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

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
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    sender = Map.get(args, :sender)
    recipient = Map.get(args, :recipient)

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

  def aex141_contract_transfers(_p, %{contract_id: contract_id} = args, %{
        context: %{state: %State{} = state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    with {:ok, contract_pk} <- AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      from = Map.get(args, :from)
      to = Map.get(args, :to)

      {filter_by, account_pk} =
        cond do
          from != nil ->
            case AeMdw.Validate.id(from, [:account_pubkey]) do
              {:ok, pk} -> {{:from, pk}, pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end

          to != nil ->
            case AeMdw.Validate.id(to, [:account_pubkey]) do
              {:ok, pk} -> {{:to, pk}, pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end

          true ->
            {{:from, nil}, nil}
        end

      case AexnTransfers.fetch_contract_transfers(
             state,
             contract_pk,
             filter_by,
             pagination,
             cursor
           ) do
        {:ok, {prev, transfer_keys, next}} ->
          {:ok,
           %{
             prev_cursor: Helpers.cursor_val(prev),
             next_cursor: Helpers.cursor_val(next),
             data:
               Enum.map(transfer_keys, fn key ->
                 AeMdwWeb.AexnView.contract_transfer_to_map(
                   state,
                   :aex141,
                   elem(filter_by, 0),
                   key,
                   true
                 )
               end)
           }}

        {:error, err} ->
          {:error, Helpers.format_err(err)}
      end
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  catch
    {:error, msg} -> {:error, msg}
  end
end
