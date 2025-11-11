defmodule AeMdwWeb.GraphQL.Schema.Types.BlockTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:key_block)

  object :key_block do
    field(:transactions_count, :integer)
    field(:micro_blocks_count, :integer)
    field(:beneficiary_reward, :big_int)
    field(:beneficiary, :string)
    field(:flags, :string)
    field(:hash, :string)
    field(:height, :integer)
    field(:info, :string)
    field(:miner, :string)
    field(:nonce, :big_int)
    field(:pow, list_of(:integer))
    field(:prev_hash, :string)
    field(:prev_key_hash, :string)
    field(:state_hash, :string)
    field(:target, :integer)
    field(:time, :integer)
    field(:version, :integer)
  end

  Macros.page(:micro_block)

  object :micro_block do
    field(:gas, :integer)
    field(:transactions_count, :integer)
    field(:micro_block_index, :integer)
    field(:flags, :string)
    field(:hash, :string)
    field(:height, :integer)
    field(:pof_hash, :string)
    field(:prev_hash, :string)
    field(:prev_key_hash, :string)
    field(:signature, :string)
    field(:state_hash, :string)
    field(:time, :integer)
    field(:txs_hash, :string)
    field(:version, :integer)
  end
end
