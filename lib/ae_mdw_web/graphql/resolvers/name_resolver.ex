defmodule AeMdwWeb.GraphQL.Resolvers.NameResolver do
  @moduledoc false

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec name(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def name(_parent, %{id: id}, %{context: %{state: state}}) do
    Helpers.make_single(Names.fetch_name(state, id, [{:render_v3?, true}]))
  end

  @spec names(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def names(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by, :expiration)

    query = Helpers.build_query(args, [:owned_by, :state, :prefix])

    Helpers.make_page(
      Names.fetch_names(state, pagination, nil, order_by, query, cursor, [{:render_v3?, true}])
    )
  end

  @spec search_names(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def search_names(_parent, %{prefix: prefix} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = %{"prefix" => prefix}

    Helpers.make_page(
      Names.fetch_names(state, pagination, nil, :name, query, cursor, [{:render_v3?, true}])
    )
  end

  def search_names(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec names_count(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def names_count(_parent, args, %{context: %{state: state}}) do
    query = Helpers.build_query(args, [:owned_by])
    Helpers.make_single(Names.count_names(state, query))
  end

  @spec name_claims(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def name_claims(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Names.fetch_name_claims(state, id, pagination, scope, cursor))
  end

  @spec name_updates(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def name_updates(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Names.fetch_name_updates(state, id, pagination, scope, cursor))
  end

  @spec name_transfers(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def name_transfers(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Names.fetch_name_transfers(state, id, pagination, scope, cursor))
  end

  @spec name_history(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def name_history(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Helpers.make_page(Names.fetch_name_history(state, pagination, id, cursor))
  end

  @spec auction(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def auction(_parent, %{id: id}, %{context: %{state: state}}) do
    Helpers.make_single(AeMdw.AuctionBids.fetch_auction(state, id, [{:render_v3?, true}]))
  end

  @spec auctions(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def auctions(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by, :expiration)

    Helpers.make_page(
      AeMdw.AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [{:render_v3?, true}])
    )
  end

  @spec auction_claims(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def auction_claims(_parent, %{id: ""}, _resolution),
    do: {:error, Helpers.format_err({ErrInput.Id, ""})}

  def auction_claims(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    case Validate.id(id) do
      {:ok, name_hash} ->
        case AeMdw.Db.Name.plain_name(state, name_hash) do
          {:ok, plain_name} ->
            Helpers.make_page(
              Names.fetch_auction_claims(state, plain_name, pagination, scope, cursor)
            )

          nil ->
            {:error, Helpers.format_err({ErrInput.NotFound, id})}
        end

      {:error, _reason} ->
        if String.printable?(id) do
          Helpers.make_page(
            Names.fetch_auction_claims(
              state,
              String.downcase(Validate.ensure_name_suffix(id)),
              pagination,
              scope,
              cursor
            )
          )
        else
          {:error, Helpers.format_err({ErrInput.Id, id})}
        end
    end
  end

  @spec account_name_claims(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def account_name_claims(_parent, %{account_id: account_id} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Names.fetch_account_claims(state, account_id, pagination, scope, cursor))
  end

  @spec account_name_pointees(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def account_name_pointees(_parent, %{account_id: account_id} = args, %{
        context: %{state: state}
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Names.fetch_pointees(state, account_id, pagination, scope, cursor))
  end
end
