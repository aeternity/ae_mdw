defmodule AeMdwWeb.GraphQL.Resolvers.StatsResolver do
  @moduledoc false

  alias AeMdw.Miners
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec transactions(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def transactions(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:tx_type, :interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_transactions_stats(state, pagination, query, nil, cursor))
  end

  @spec transactions_total(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def transactions_total(_parent, args, %{context: %{state: state}}) do
    query = Helpers.build_query(args, [:tx_type, :min_start_date, :max_start_date])

    Helpers.make_single(Stats.fetch_transactions_total_stats(state, query, nil))
  end

  @spec blocks(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def blocks(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:tx_type, :interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_blocks_stats(state, pagination, query, nil, cursor))
  end

  @spec difficulty(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def difficulty(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_difficulty_stats(state, pagination, query, nil, cursor))
  end

  @spec hashrate(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def hashrate(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_hashrate_stats(state, pagination, query, nil, cursor))
  end

  @spec total_accounts(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def total_accounts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by])

    Helpers.make_page(Stats.fetch_total_accounts_stats(state, pagination, query, nil, cursor))
  end

  @spec active_accounts(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def active_accounts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by])

    Helpers.make_page(Stats.fetch_active_accounts_stats(state, pagination, query, nil, cursor))
  end

  @spec names(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def names(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_names_stats(state, pagination, query, nil, cursor))
  end

  @spec total(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def total(_parent, args, %{context: %{state: state}}) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} =
      Helpers.pagination_args_all_with_scope(args)

    Helpers.make_page(Stats.fetch_total_stats(state, direction, scope, cursor, limit))
  end

  @spec delta(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def delta(_parent, args, %{context: %{state: state}}) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} =
      Helpers.pagination_args_all_with_scope(args)

    Helpers.make_page(Stats.fetch_delta_stats(state, direction, scope, cursor, limit))
  end

  @spec contracts(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def contracts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_contracts_stats(state, pagination, query, nil, cursor))
  end

  @spec aex9_transfers(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def aex9_transfers(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(
      Stats.fetch_aex9_token_transfers_stats(state, pagination, query, nil, cursor)
    )
  end

  @spec stats(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def stats(_parent, _args, %{context: %{state: state}}) do
    Helpers.make_single(Stats.fetch_stats(state))
  end

  @spec miners(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def miners(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Helpers.make_page(Miners.fetch_miners(state, pagination, cursor))
  end

  @spec top_miners(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def top_miners(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(Stats.fetch_top_miners_stats(state, pagination, query, nil, cursor))
  end

  @spec top_miners_24h(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def top_miners_24h(_parent, _args, %{context: %{state: state}}) do
    {:ok,
     %{
       data: Stats.fetch_top_miners_24hs(state)
     }}
  end
end
