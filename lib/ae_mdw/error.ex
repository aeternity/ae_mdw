defmodule AeMdw.Error do
  @moduledoc """
  Custom application errors definition.
  """

  alias AeMdw.Error.Input

  import AeMdwWeb.Util, only: [concat: 2]

  @type t() :: Input.t()
  @type value() :: any()

  @spec to_string(Input.reason(), value()) :: Input.message()
  def to_string(Input.Id, x), do: concat("invalid id", x)
  def to_string(Input.BlockIndex, x), do: concat("invalid block index", x)
  def to_string(Input.NonnegInt, x), do: concat("invalid non-negative integer", x)
  def to_string(Input.TxField, x), do: concat("invalid transaction field", x)
  def to_string(Input.TxType, x), do: concat("invalid transaction type", x)
  def to_string(Input.TxGroup, x), do: concat("invalid transaction group", x)
  def to_string(Input.Cursor, x), do: concat("invalid cursor", x)
  def to_string(Input.Scope, x), do: concat("invalid scope", x)
  def to_string(Input.Query, x), do: concat("invalid query", x)
  def to_string(Input.NotFound, x), do: concat("not found", x)
  def to_string(Input.Expired, x), do: concat("expired", x)
  def to_string(Input.NotAex9, x), do: concat("not AEX9 contract", x)
  def to_string(Input.NotAex141, x), do: concat("not AEX141 contract", x)
  def to_string(Input.ContractReturn, x), do: concat("invalid return of contract", x)
  def to_string(Input.ContractDryRun, x), do: concat("error calling contract", x)
  def to_string(Input.Aex9BalanceNotAvailable, x), do: concat("balance is not available", x)
  def to_string(Input.Base64, x), do: concat("invalid base64 encoding", x)
  def to_string(Input.Hex32, x), do: concat("invalid hex32 encoding", x)
  def to_string(Input.RangeTooBig, x), do: concat("invalid range", x)

  defmodule Input do
    require AeMdw.Exception
    import AeMdw.Exception, only: [defexception!: 1]

    defexception [:reason, :message]

    @type reason() ::
            __MODULE__.Id
            | __MODULE__.BlockIndex
            | __MODULE__.NonnegInt
            | __MODULE__.TxField
            | __MODULE__.TxType
            | __MODULE__.TxGroup
            | __MODULE__.Scope
            | __MODULE__.Query
            | __MODULE__.NotFound
            | __MODULE__.Expired
            | __MODULE__.NotAex9
            | __MODULE__.NotAex141
            | __MODULE__.ContractReturn
            | __MODULE__.ContractDryRun
            | __MODULE__.Aex9BalanceNotAvailable
            | __MODULE__.Base64
            | __MODULE__.Hex32
            | __MODULE__.RangeTooBig
    @type message() :: binary()
    @type t() :: %__MODULE__{
            reason: reason(),
            message: message()
          }

    defexception!(Id)
    defexception!(BlockIndex)
    defexception!(NonnegInt)
    defexception!(TxField)
    defexception!(TxType)
    defexception!(TxGroup)
    defexception!(Cursor)
    defexception!(Scope)
    defexception!(Query)
    defexception!(NotFound)
    defexception!(Expired)
    defexception!(NotAex9)
    defexception!(NotAex141)
    defexception!(ContractReturn)
    defexception!(ContractDryRun)
    defexception!(Aex9BalanceNotAvailable)
    defexception!(Base64)
    defexception!(Hex32)
    defexception!(RangeTooBig)
  end
end
