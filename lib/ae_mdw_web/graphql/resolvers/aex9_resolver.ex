defmodule AeMdwWeb.GraphQL.Resolvers.Aex9Resolver do
  @moduledoc false

  alias AeMdw.AexnTokens
  alias AeMdw.Aex9
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  require Model

  @spec aex9_count(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def aex9_count(_parent, _args, %{context: %{state: state}}) do
    count =
      case State.get(state, Model.Stat, Stats.aexn_count_key(:aex9)) do
        {:ok, Model.stat(payload: count)} -> count
        :not_found -> 0
      end

    {:ok, count}
  end

  @spec aex9_contracts(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_contracts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query = Helpers.build_query(args, [:prefix, :exact])

    Helpers.make_page(
      AexnTokens.fetch_contracts(state, pagination, :aex9, query, order_by, cursor, true)
    )
  end

  @spec aex9_contract(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_contract(_parent, %{id: id}, %{context: %{state: state}}) do
    Helpers.make_single(AexnTokens.fetch_contract(state, :aex9, id, true))
  end

  @spec aex9_contract_balances(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_contract_balances(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query = Helpers.build_query(args, [:block_hash])

    Helpers.make_page(Aex9.fetch_event_balances(state, id, pagination, cursor, order_by, query))
  end

  @spec aex9_balance_history(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_balance_history(_parent, %{contract_id: cid, account_id: aid} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    with {:ok, contract_pk} <- AeMdw.Validate.id(cid, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]) do
      Helpers.make_page(
        Aex9.fetch_balance_history(state, contract_pk, account_pk, scope, cursor, pagination)
      )
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec aex9_token_balance(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_token_balance(_parent, %{contract_id: cid, account_id: aid} = args, _ctx) do
    with {:ok, contract_pk} <- AeMdw.Validate.id(cid, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]),
         {:ok, height_hash} <- resolve_block_hash(args) do
      Helpers.make_single(Aex9.fetch_balance(contract_pk, account_pk, height_hash))
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec aex9_account_balances(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_account_balances(_parent, %{account_id: aid} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case AeMdw.Validate.id(aid, [:account_pubkey]) do
      {:ok, account_pk} ->
        Helpers.make_page(Aex9.fetch_account_balances(state, account_pk, cursor, pagination))

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec aex9_contract_transfers(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_contract_transfers(_parent, %{contract_id: contract_id} = args, %{
        context: %{state: %State{} = state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    sender = Map.get(args, :sender)
    recipient = Map.get(args, :recipient)
    account = Map.get(args, :account)

    with {:ok, contract_pk} <- AeMdw.Validate.id(contract_id, [:contract_pubkey]),
         {:ok, filter_by} <- resolve_aex9_filter(sender, recipient, account) do
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
      {:error, msg} when is_binary(msg) -> {:error, msg}
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  defp resolve_block_hash(args) do
    case Map.get(args, :hash) do
      nil ->
        {:ok, nil}

      hash ->
        case AeMdw.Validate.id(hash, [:key_block_hash, :micro_block_hash]) do
          {:ok, block_hash_pk} -> {:ok, {:hash, block_hash_pk}}
          {:error, _} = error -> error
        end
    end
  end

  defp resolve_aex9_filter(sender, _recipient, _account) when sender != nil do
    case AeMdw.Validate.id(sender, [:account_pubkey]) do
      {:ok, pk} -> {:ok, {:from, pk}}
      {:error, _} = error -> error
    end
  end

  defp resolve_aex9_filter(_sender, recipient, _account) when recipient != nil do
    case AeMdw.Validate.id(recipient, [:account_pubkey]) do
      {:ok, pk} -> {:ok, {:to, pk}}
      {:error, _} = error -> error
    end
  end

  defp resolve_aex9_filter(_sender, _recipient, account) when account != nil do
    case AeMdw.Validate.id(account, [:account_pubkey]) do
      {:ok, pk} -> {:ok, {nil, pk}}
      {:error, _} = error -> error
    end
  end

  defp resolve_aex9_filter(_sender, _recipient, _account) do
    {:error, "sender, recipient, or account param is required"}
  end
end
