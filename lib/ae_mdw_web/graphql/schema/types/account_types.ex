defmodule AeMdwWeb.GraphQL.Schema.Types.AccountTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:account)

  object :account do
    field(:id, non_null(:string))
    # Large balance uses custom BigInt scalar (no 32-bit restriction)
    field(:balance, :big_int)
    field(:creation_time, :integer)
    field(:nonce, :integer)
    field(:names_count, :integer)
    field(:activities_count, :integer, description: "Number of recorded activity intervals")
  end

  Macros.page(:aex9_balance)

  object :aex9_balance do
    field(:contract_id, :string)
    field(:amount, :big_int)
  end
end
