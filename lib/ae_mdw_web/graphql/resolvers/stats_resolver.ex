defmodule AeMdwWeb.GraphQL.Resolvers.StatsResolver do
  alias AeMdw.Miners
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def transactions(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:tx_type, :interval_by, :min_start_date, :max_start_date])

    Stats.fetch_transactions_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def transactions_total(_p, args, %{context: %{state: state}}) do
    query = Helpers.build_query(args, [:tx_type, :min_start_date, :max_start_date])
    Stats.fetch_transactions_total_stats(state, query, nil)
  end

  def blocks(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:tx_type, :interval_by, :min_start_date, :max_start_date])

    Stats.fetch_blocks_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def difficulty(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Stats.fetch_difficulty_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def hashrate(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Stats.fetch_hashrate_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def total_accounts(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by])

    Stats.fetch_total_accounts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def active_accounts(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by])

    Stats.fetch_active_accounts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def names(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Stats.fetch_names_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def total(_p, args, %{context: %{state: state}}) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} =
      Helpers.pagination_args_all_with_scope(args)

    Stats.fetch_total_stats(state, direction, scope, cursor, limit)
    |> Helpers.make_page()
  end

  def delta(_p, args, %{context: %{state: state}}) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} =
      Helpers.pagination_args_all_with_scope(args)

    Stats.fetch_delta_stats(state, direction, scope, cursor, limit)
    |> Helpers.make_page()
  end

  def contracts(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Stats.fetch_contracts_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def aex9_transfers(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Stats.fetch_aex9_token_transfers_stats(state, pagination, query, nil, cursor)
    |> Helpers.make_page()
  end

  def stats(_p, _args, %{context: %{state: state}}) do
    Stats.fetch_stats(state)
  end

  def miners(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Miners.fetch_miners(state, pagination, cursor)
    |> Helpers.make_page()
  end

  def top_miners(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

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
