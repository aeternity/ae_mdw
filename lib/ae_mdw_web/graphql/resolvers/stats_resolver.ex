defmodule AeMdwWeb.GraphQL.Resolvers.StatsResolver do
  alias AeMdw.Miners
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def transactions(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "tx_type", Map.get(args, :tx_type))

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_transactions_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def transactions_total(_p, args, %{context: %{state: state}}) do
    query = %{}
    query = Helpers.maybe_put(query, "tx_type", Map.get(args, :tx_type))
    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_transactions_total_stats(state, query, nil)
  end

  def blocks(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(query, "type", Map.get(args, :type) |> Helpers.maybe_map(&to_string/1))

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_blocks_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def difficulty(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_difficulty_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def hashrate(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_hashrate_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def total_accounts(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    Stats.fetch_total_accounts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def active_accounts(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    Stats.fetch_active_accounts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def names(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_names_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def total(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)

    Stats.fetch_total_stats(state, direction, scope, cursor, limit)
    |> Helpers.make_page()
  end

  def delta(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)

    Stats.fetch_delta_stats(state, direction, scope, cursor, limit)
    |> Helpers.make_page()
  end

  def contracts(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_contracts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def aex9_transfers(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_aex9_token_transfers_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def stats(_p, _args, %{context: %{state: state}}) do
    Stats.fetch_stats(state)
  end

  def miners(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Miners.fetch_miners(state, pagination, cursor)
    |> Helpers.make_page()
  end

  def top_miners(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "interval_by",
        Map.get(args, :interval_by) |> Helpers.maybe_map(&to_string/1)
      )

    query = Helpers.maybe_put(query, "min_start_date", Map.get(args, :min_start_date))
    query = Helpers.maybe_put(query, "max_start_date", Map.get(args, :max_start_date))

    Stats.fetch_top_miners_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def top_miners_24h(_p, _args, %{context: %{state: state}}) do
    {:ok,
     %{
       data: Stats.fetch_top_miners_24hs(state)
     }}
  end
end
