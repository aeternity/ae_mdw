defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  alias AeMdw.Contracts
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec contract(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def contract(_parent, %{id: id}, %{context: %{state: state}}) do
    Contracts.fetch_contract(state, id) |> Helpers.make_single()
  end

  @spec contracts(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def contracts(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Contracts.fetch_contracts(state, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  @spec logs(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def logs(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query =
      Helpers.build_query(args, [
        :contract_id,
        :event,
        :function,
        :function_prefix,
        :data,
        :aexn_args
      ])

    Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: true)
    |> Helpers.make_page()
  end

  @spec calls(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def calls(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:function, :function_prefix, :aexn_args])

    Contracts.fetch_calls(state, pagination, scope, query, cursor, v3?: true)
    |> Helpers.make_page()
  end

  @spec contract_logs(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def contract_logs(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query =
      Helpers.build_query(args, [
        :contract_id,
        :event,
        :function,
        :function_prefix,
        :data,
        :aexn_args
      ])

    Contracts.fetch_contract_logs(state, id, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end

  @spec contract_calls(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def contract_calls(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:function, :function_prefix, :aexn_args])

    Contracts.fetch_contract_calls(state, id, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end
end
