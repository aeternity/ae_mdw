defmodule AeMdwWeb.GraphQL.Schema.Queries.BlockQueries do
  use Absinthe.Schema.Notation

  object :block_queries do
    @desc "Fetch a key block by height or hash"
    field :key_block, :key_block do
      arg(:id, non_null(:string), description: "Height (integer as string) or key block hash")
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_block/3)
    end

    @desc "Fetch a micro block by its hash"
    field :micro_block, :micro_block do
      arg(:hash, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.micro_block/3)
    end

    @desc "Paginated key blocks (optionally by generation range)"
    field :key_blocks, :key_block_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_blocks/3)
    end
  end
end
