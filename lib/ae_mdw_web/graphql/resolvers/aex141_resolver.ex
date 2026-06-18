defmodule AeMdwWeb.GraphQL.Resolvers.Aex141Resolver do
  @moduledoc false

  alias AeMdw.Aex141
  alias AeMdw.AexnTokens
  alias AeMdw.AexnTransfers
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  @spec aex141_count(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_count(_parent, _args, %{context: %{state: state}}) do
    count =
      case State.get(state, Model.Stat, Stats.aexn_count_key(:aex141)) do
        {:ok, Model.stat(payload: count)} -> count
        :not_found -> 0
      end

    {:ok, count}
  end

  @spec aex141_contracts(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contracts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by)

    query = Helpers.build_query(args, [:prefix, :exact])

    Helpers.make_page(
      AexnTokens.fetch_contracts(state, pagination, :aex141, query, order_by, cursor, true)
    )
  end

  @spec aex141_contract(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract(_parent, %{id: id}, %{context: %{state: state}}) do
    Helpers.make_single(AexnTokens.fetch_contract(state, :aex141, id, true))
  end

  @spec aex141_transfers(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_transfers(_parent, args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:from, :to])

    # Custom mapping with state is required (pair_transfer_to_map/2 takes state
    # as first arg), so Helpers.make_page/1 cannot be used directly here.
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

  @spec aex141_contract_transfers(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract_transfers(_parent, %{contract_id: contract_id} = args, %{
        context: %{state: %State{} = state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    from = Map.get(args, :from)
    to = Map.get(args, :to)

    with {:ok, contract_pk} <- AeMdw.Validate.id(contract_id, [:contract_pubkey]),
         {:ok, filter_by} <- resolve_aex141_filter(from, to) do
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
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  @spec aex141_contract_token(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract_token(_parent, %{contract_id: contract_id, token_id: token_id}, %{
        context: %{state: state}
      }) do
    Helpers.make_single(Aex141.fetch_nft(state, contract_id, token_id, v3?: true))
  end

  @spec aex141_contract_tokens(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract_tokens(_parent, %{contract_id: contract_id} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      {:ok, contract_pk} ->
        Helpers.make_page(Aex141.fetch_collection_owners(state, contract_pk, cursor, pagination))

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec aex141_account_tokens(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_account_tokens(_parent, %{account_id: account_id} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    query = Helpers.build_query(args, [:contract])

    Helpers.make_page(Aex141.fetch_owned_tokens(state, account_id, cursor, pagination, query))
  end

  @spec aex141_contract_templates(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract_templates(_parent, %{contract_id: contract_id} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      {:ok, contract_pk} ->
        Helpers.make_page(Aex141.fetch_templates(state, contract_pk, cursor, pagination))

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec aex141_contract_template_tokens(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex141_contract_template_tokens(
        _parent,
        %{contract_id: contract_id, template_id: template_id} = args,
        %{context: %{state: state}}
      ) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      {:ok, contract_pk} ->
        Helpers.make_page(
          Aex141.fetch_template_tokens(state, contract_pk, template_id, cursor, pagination)
        )

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  defp resolve_aex141_filter(from, _to) when from != nil do
    case AeMdw.Validate.id(from, [:account_pubkey]) do
      {:ok, pk} -> {:ok, {:from, pk}}
      {:error, _} = error -> error
    end
  end

  defp resolve_aex141_filter(_from, to) when to != nil do
    case AeMdw.Validate.id(to, [:account_pubkey]) do
      {:ok, pk} -> {:ok, {:to, pk}}
      {:error, _} = error -> error
    end
  end

  defp resolve_aex141_filter(_from, _to) do
    {:ok, {:from, nil}}
  end
end
