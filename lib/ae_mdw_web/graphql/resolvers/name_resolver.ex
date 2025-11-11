defmodule AeMdwWeb.GraphQL.Resolvers.NameResolver do
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def name(_p, %{id: id}, %{context: %{state: state}}) do
    Names.fetch_name(state, id, [{:render_v3?, true}]) |> Helpers.make_single()
  end

  def names(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by, :expiration)

    query = Helpers.build_query(args, [:owned_by, :state, :prefix])

    Names.fetch_names(state, pagination, nil, order_by, query, cursor, [{:render_v3?, true}])
    |> Helpers.make_page()
  end

  def names_count(_p, args, %{context: %{state: state}}) do
    query = Helpers.build_query(args, [:owned_by])
    Names.count_names(state, query) |> Helpers.make_single()
  end

  def name_claims(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Names.fetch_name_claims(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def name_updates(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Names.fetch_name_updates(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def name_transfers(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Names.fetch_name_transfers(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def name_history(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Names.fetch_name_history(state, pagination, id, cursor)
    |> Helpers.make_page()
  end

  def auction(_p, %{id: id}, %{context: %{state: state}}) do
    AeMdw.AuctionBids.fetch_auction(state, id, [{:render_v3?, true}]) |> Helpers.make_single()
  end

  def auctions(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    order_by = Map.get(args, :order_by, :expiration)

    AeMdw.AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [{:render_v3?, true}])
    |> Helpers.make_page()
  end

  def auction_claims(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    with {:ok, plain_name} <- Validate.plain_name(state, id) do
      Names.fetch_auction_claims(state, plain_name, pagination, scope, cursor)
      |> Helpers.make_page()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  def account_name_claims(_p, %{account_id: account_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Names.fetch_account_claims(state, account_id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def account_name_pointees(_p, %{account_id: account_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Names.fetch_pointees(state, account_id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end
