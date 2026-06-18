defmodule AeMdwWeb.GraphQL.Schema.Types.TransactionTypes do
  @moduledoc false

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
    field(:tx_index, :integer)
  end
end
