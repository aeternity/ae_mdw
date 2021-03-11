defmodule AeMdw.Error do
  alias AeMdw.Error.Input, as: Err

  import AeMdwWeb.Util, only: [concat: 2]

  def to_string(Err.Id, x), do: concat("invalid id", x)
  def to_string(Err.BlockIndex, x), do: concat("invalid block index", x)
  def to_string(Err.NonnegInt, x), do: concat("invalid non-negative integer", x)
  def to_string(Err.TxField, x), do: concat("invalid transaction field", x)
  def to_string(Err.TxType, x), do: concat("invalid transaction type", x)
  def to_string(Err.TxGroup, x), do: concat("invalid transaction group", x)
  def to_string(Err.Scope, x), do: concat("invalid scope", x)
  def to_string(Err.Query, x), do: concat("invalid query", x)
  def to_string(Err.NotFound, x), do: concat("not found", x)
  def to_string(Err.Expired, x), do: concat("expired", x)
  def to_string(Err.NotAex9, x), do: concat("not AEX9 contract", x)
  def to_string(Err.Base64, x), do: concat("invalid base64 encoding", x)
  def to_string(Err.Hex32, x), do: concat("invalid hex32 encoding", x)

  defmodule Input do
    require AeMdw.Exception
    import AeMdw.Exception, only: [defexception!: 1]

    defexception [:reason, :message]

    defexception!(Id)
    defexception!(BlockIndex)
    defexception!(NonnegInt)
    defexception!(TxField)
    defexception!(TxType)
    defexception!(TxGroup)
    defexception!(Scope)
    defexception!(Query)
    defexception!(NotFound)
    defexception!(Expired)
    defexception!(NotAex9)
    defexception!(Base64)
    defexception!(Hex32)
  end
end
