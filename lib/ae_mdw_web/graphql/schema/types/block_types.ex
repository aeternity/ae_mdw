defmodule AeMdwWeb.GraphQL.Schema.Types.BlockTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:key_block)

  object :key_block do
    field(:hash, non_null(:string))
    field(:height, non_null(:integer))
    field(:time, non_null(:integer))

    field(:miner, :string,
      resolve: fn blk, _, _ -> {:ok, blk[:beneficiary] || blk["beneficiary"]} end
    )

    field(:micro_blocks_count, :integer)
    field(:transactions_count, :integer)
    field(:beneficiary_reward, :integer)
    # extra enrichment
    field(:info, :string, description: "Consensus protocol / version JSON (serialized)")
    field(:pow, :string, description: "Proof-of-work info if present")
    field(:nonce, :string)
    field(:version, :integer)
    field(:target, :integer)
    field(:state_hash, :string)
    field(:prev_key_hash, :string)
    field(:prev_hash, :string)
    field(:beneficiary, :string)
  end

  Macros.page(:micro_block)

  object :micro_block do
    field(:hash, non_null(:string))
    field(:height, non_null(:integer))
    field(:time, non_null(:integer))
    field(:micro_block_index, :integer)
    field(:transactions_count, :integer)
    field(:gas, :integer)
    # enrichment
    field(:pof_hash, :string)
    field(:prev_hash, :string)
    field(:state_hash, :string)
    field(:txs_hash, :string)
    field(:signature, :string)
    field(:miner, :string)
  end
end
