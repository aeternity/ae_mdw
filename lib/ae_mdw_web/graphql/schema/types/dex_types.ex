defmodule AeMdwWeb.GraphQL.Schema.Types.DexTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:swap)

  object :swap do
    field(:caller, :string)
    field(:action, :string)
    field(:height, :integer)
    field(:tx_hash, :string)
    field(:log_idx, :integer)
    field(:amounts, :json)
    field(:micro_time, :integer)
    field(:from_amount, :big_int)
    field(:from_contract, :string)
    field(:from_decimals, :integer)
    field(:from_token, :string)
    field(:to_account, :string)
    field(:to_amount, :big_int)
    field(:to_contract, :string)
    field(:to_decimals, :integer)
    field(:to_token, :string)
  end
end
