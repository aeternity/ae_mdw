defmodule AeMdw.Error do
  alias AeMdw.Error.Input, as: Err

  import AeMdwWeb.Util, only: [concat: 2]

  def to_string(Err.Id, x), do: concat("invalid id", x)
  def to_string(Err.NonnegInt, x), do: concat("invalid non-negative integer", x)
  def to_string(Err.TxField, x), do: concat("invalid transaction field", x)
  def to_string(Err.TxType, x), do: concat("invalid transaction type", x)
  def to_string(Err.TxGroup, x), do: concat("invalid transaction group", x)
  def to_string(Err.Scope, x), do: concat("invalid scope", x)
  def to_string(Err.Query, x), do: concat("invalid query", x)

  defmodule Input do
    require AeMdw.Exception
    import AeMdw.Exception, only: [defexception!: 1]

    defexception [:message]

    defexception! Id
    defexception! NonnegInt
    defexception! TxField
    defexception! TxType
    defexception! TxGroup
    defexception! Scope
    defexception! Query
  end
end
