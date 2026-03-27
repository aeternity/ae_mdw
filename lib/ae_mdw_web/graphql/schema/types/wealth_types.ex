defmodule AeMdwWeb.GraphQL.Schema.Types.WealthTypes do
  use Absinthe.Schema.Notation

  object :wealth_entry do
    field(:account, :string)
    field(:balance, :big_int)
  end

  object :wealth_page do
    field(:data, list_of(:wealth_entry))
  end
end
