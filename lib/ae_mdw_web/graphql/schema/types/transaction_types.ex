defmodule AeMdwWeb.GraphQL.Schema.Types.TransactionTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:transaction)

  object :transaction do
    field(:block_hash, :string)
    field(:block_height, :integer)
    field(:encoded_tx, :string)
    field(:hash, :string)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
    field(:signatures, list_of(:string))
    field(:tx, :json)
  end

  #input_object :transaction_filter do
  #  field(:account, :string)
  #  field(:type, :string)
  #  field(:from_height, :integer)
  #  field(:to_height, :integer)
  #end
end
