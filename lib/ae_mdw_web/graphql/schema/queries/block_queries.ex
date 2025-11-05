defmodule AeMdwWeb.GraphQL.Schema.Queries.BlockQueries do
  use Absinthe.Schema.Notation

  object :block_queries do
    @desc "Fetch key blocks"
    field :key_blocks, :key_block_page do
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_blocks/3)
    end

    @desc "Fetch the key block at the given height"
    field :key_block_at_height, :key_block do
      arg(:height, non_null(:integer))
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_block/3)
    end

    @desc "Fetch the key block with the given hash"
    field :key_block_with_hash, :key_block do
      arg(:hash, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_block/3)
    end

    # @desc "Fetch micro blocks of the key block at the given height"
    # field :micro_blocks_of_key_block_at_height, :micro_block_page do
    # arg(:height, non_null(:integer))
    # resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.micro_blocks/3)
    # end

    # @desc "Fetch micro blocks of the key block with the given hash"
    # field :micro_blocks_of_key_block_with_hash, :micro_block_page do
    # arg(:hash, non_null(:string))
    # resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.micro_blocks/3)
    # end

    # @desc "Fetch the micro block with the given hash"
    # field :micro_block, :micro_block do
    # arg(:hash, non_null(:string))
    # resolve(&AeMdwWeb.GraphQL.Resolvers.BlockResolver.micro_block/3)
    # end
  end
end
