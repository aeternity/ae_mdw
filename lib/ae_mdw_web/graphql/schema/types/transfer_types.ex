defmodule AeMdwWeb.GraphQL.Schema.Types.TransferTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  Macros.page(:transfer)

  object :transfer do
    field(:kind, :string)
    field(:height, :integer)
    field(:amount, :big_int)
    field(:account_id, :string)
    field(:ref_tx_hash, :string)
    field(:ref_block_hash, :string)
    field(:ref_tx_type, :string)
  end
end
