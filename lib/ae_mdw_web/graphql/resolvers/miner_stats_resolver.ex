defmodule AeMdwWeb.GraphQL.Resolvers.MinerStatsResolver do
  @moduledoc false

  alias AeMdw.MinerStats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec summary(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def summary(_parent, _args, %{context: %{state: state}}) do
    Helpers.make_single(MinerStats.fetch_summary(state))
  end

  @spec miners(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def miners(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:role])

    Helpers.make_page(
      MinerStats.fetch_miners(state, pagination, query, Map.get(args, :order_by), cursor)
    )
  end

  @spec miner(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def miner(_parent, %{id: id} = args, %{context: %{state: state}}) do
    query = Helpers.build_query(args, [:role])

    Helpers.make_single(MinerStats.fetch_miner(state, query, id))
  end

  @spec links(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def links(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Helpers.make_page(MinerStats.fetch_links(state, pagination, %{}, id, cursor))
  end

  @spec miner_series(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def miner_series(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:role, :interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(MinerStats.fetch_miner_series(state, pagination, id, scope, query, cursor))
  end

  @spec mining_series(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def mining_series(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:interval_by, :min_start_date, :max_start_date])

    Helpers.make_page(MinerStats.fetch_network_series(state, pagination, scope, query, cursor))
  end

  @spec bucket(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def bucket(_parent, %{bucket: bucket}, %{context: %{state: state}}) do
    Helpers.make_single(MinerStats.fetch_bucket(state, bucket))
  end

  @spec bucket_miners(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def bucket_miners(_parent, %{bucket: bucket} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = Helpers.build_query(args, [:role])

    Helpers.make_page(MinerStats.fetch_bucket_miners(state, pagination, bucket, query, cursor))
  end
end
