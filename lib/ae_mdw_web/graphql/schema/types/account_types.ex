defmodule AeMdwWeb.GraphQL.Schema.Types.AccountTypes do
  @moduledoc false

  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  enum :activity_type do
    value(:transactions)
    value(:aexn)
    value(:aex9)
    value(:aex141)
    value(:contract)
    value(:transfers)
    value(:claims)
    value(:swaps)
  end

  object :account do
    field(:id, :string)
    field(:balance, :big_int)
    field(:creation_time, :integer)
  end

  Macros.page(:account_activity)

  object :account_activity do
    field(:type, :string)
    field(:height, :integer)
    field(:block_hash, :string)
    field(:payload, :json)
    field(:block_time, :integer)
  end
end
