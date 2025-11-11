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

    query = Helpers.build_query(args, [:prefix, :exact])

    AexnTokens.fetch_contracts(state, pagination, :aex9, query, order_by, cursor, true)
    |> Helpers.make_page()
  end

  def aex9_contract(_p, %{id: id}, %{context: %{state: state}}) do
    AexnTokens.fetch_contract(state, :aex9, id, true) |> Helpers.make_single()
  end

  def aex9_contract_balances(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query = Helpers.build_query(args, [:block_hash])

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

  def aex9_token_balance(_p, %{contract_id: cid, account_id: aid} = args, _ctx) do
    with {:ok, contract_pk} <- AeMdw.Validate.id(cid, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]) do
      block_hash = Map.get(args, :hash)

      height_hash =
        case block_hash do
          nil ->
            nil

          hash ->
            case AeMdw.Validate.id(hash, [:key_block_hash, :micro_block_hash]) do
              {:ok, block_hash_pk} -> {:hash, block_hash_pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end
        end

      Aex9.fetch_balance(contract_pk, account_pk, height_hash) |> Helpers.make_single()
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  catch
    {:error, msg} -> {:error, msg}
  end

  def aex9_account_balances(_p, %{account_id: aid} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    with {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]) do
      Aex9.fetch_account_balances(state, account_pk, cursor, pagination) |> Helpers.make_page()
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  def aex9_contract_transfers(_p, %{contract_id: contract_id} = args, %{
        context: %{state: %State{} = state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    with {:ok, contract_pk} <- AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      sender = Map.get(args, :sender)
      recipient = Map.get(args, :recipient)
      account = Map.get(args, :account)

      filter_by =
        cond do
          sender != nil ->
            case AeMdw.Validate.id(sender, [:account_pubkey]) do
              {:ok, pk} -> {:from, pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end

          recipient != nil ->
            case AeMdw.Validate.id(recipient, [:account_pubkey]) do
              {:ok, pk} -> {:to, pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end

          account != nil ->
            case AeMdw.Validate.id(account, [:account_pubkey]) do
              {:ok, pk} -> {nil, pk}
              {:error, err} -> throw({:error, Helpers.format_err(err)})
            end

          true ->
            {:error, "sender, recipient, or account param is required"}
            |> throw()
        end

      case AeMdw.AexnTransfers.fetch_contract_transfers(
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
                   :aex9,
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
