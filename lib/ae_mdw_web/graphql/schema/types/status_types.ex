defmodule AeMdwWeb.GraphQL.Schema.Types.StatusTypes do
  use Absinthe.Schema.Notation

  object :status do
    field(:last_synced_height, non_null(:integer))
    field(:last_key_block_hash, :string)
    field(:last_key_block_time, :integer)
    field(:total_transactions, :integer)
    field(:pending_transactions, :integer)
    field(:partial, non_null(:boolean))
  end

  object :sync_status do
    field(:last_synced_height, non_null(:integer))
    field(:partial, non_null(:boolean))
  end
end
