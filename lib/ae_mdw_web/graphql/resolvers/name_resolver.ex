defmodule AeMdwWeb.GraphQL.Resolvers.NameResolver do
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def name(_p, %{id: id}, %{context: %{state: state}}) do
    Names.fetch_name(state, id, [{:render_v3?, true}]) |> Helpers.make_single()
  end

  def names(_p, args, %{context: %{state: state}}) do
    order_by = Map.get(args, :order_by, :expiration)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "owned_by", Map.get(args, :owned_by))

    query =
      Helpers.maybe_put(query, "state", Map.get(args, :state) |> Helpers.maybe_map(&to_string/1))

    query = Helpers.maybe_put(query, "prefix", Map.get(args, :prefix))

    Names.fetch_names(state, pagination, nil, order_by, query, cursor, [{:render_v3?, true}])
    |> Helpers.make_page()
  end

  def names_count(_p, args, %{context: %{state: state}}) do
    query = %{}
    query = Helpers.maybe_put(query, "owned_by", Map.get(args, :owned_by))

    Names.count_names(state, query) |> Helpers.make_single()
  end

  def name_claims(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Names.fetch_name_claims(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def auction(_p, %{id: id}, %{context: %{state: state}}) do
    AeMdw.AuctionBids.fetch_auction(state, id, [{:render_v3?, true}]) |> Helpers.make_single()
  end

  def auctions(_p, args, %{context: %{state: state}}) do
    order_by = Map.get(args, :order_by, :expiration)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    AeMdw.AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [{:render_v3?, true}])
    |> Helpers.make_page()
  end

  def auction_claims(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    with {:ok, plain_name} <- Validate.plain_name(state, id) do
      Names.fetch_auction_claims(state, plain_name, pagination, scope, cursor)
      |> Helpers.make_page()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  def account_name_claims(_p, %{account_id: account_id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Names.fetch_account_claims(state, account_id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end
