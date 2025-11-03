defmodule AeMdwWeb.GraphQL.Schema.Queries.ContractQueries do
  use Absinthe.Schema.Notation

  object :contract_queries do
    @desc "Contracts"
    field :contracts, :contract_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.contracts/3)
    end

    @desc "Contract by id"
    field :contract, :contract do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.contract/3)
    end

    @desc "Contract logs"
    field :contracts_logs, :contract_log_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:contract_id, :string)
      arg(:data_prefix, :string)
      arg(:event, :string)
      arg(:function, :string)
      arg(:function_prefix, :string)
      arg(:aexn_args, :boolean)
      arg(:custom_args, :boolean)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.logs/3)
    end

    @desc "Contract logs for a specific contract"
    field :contract_logs, :contract_log_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:data_prefix, :string)
      arg(:event, :string)
      arg(:function, :string)
      arg(:function_prefix, :string)
      arg(:aexn_args, :boolean)
      arg(:custom_args, :boolean)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.contract_logs/3)
    end

    @desc "Contract calls"
    field :contracts_calls, :contract_call_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:contract_id, :string)
      arg(:function, :string)
      arg(:function_prefix, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.calls/3)
    end

    @desc "Contract calls for a specific contract"
    field :contract_calls, :contract_call_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:function, :string)
      arg(:function_prefix, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ContractResolver.contract_calls/3)
    end
  end
end
