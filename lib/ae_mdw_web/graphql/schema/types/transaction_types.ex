defmodule AeMdwWeb.GraphQL.Schema.Types.TransactionTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:transaction)

  object :transaction do
    field(:hash, :string)
    field(:block_hash, :string)
    field(:block_height, :integer)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
    field(:tx_index, :integer)
    field(:signatures, list_of(:string))
    field(:tx, :string, description: "Underlying tx object encoded as JSON string")
    # enrichment (common tx metadata)
    field(:fee, :integer)
    field(:type, :string)
    field(:gas, :integer)
    field(:gas_price, :integer)
    field(:nonce, :integer)
    field(:sender_id, :string)
    field(:recipient_id, :string)
    field(:amount, :integer)
    field(:ttl, :integer)
    field(:payload, :string)
  end

  input_object :transaction_filter do
    field(:account, :string)
    field(:type, :string)
    field(:from_height, :integer)
    field(:to_height, :integer)
  end
end
