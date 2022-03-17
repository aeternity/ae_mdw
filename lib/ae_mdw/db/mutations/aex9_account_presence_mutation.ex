defmodule AeMdw.Db.Aex9AccountPresenceMutation do
  @moduledoc """
  Computes and derives Aex9 tokens, and stores it into the appropriate indexes.
  """

  alias AeMdw.Db.Sync
  alias AeMdw.Blocks

  @derive AeMdw.Db.TxnMutation
  defstruct [:height, :mbi]

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            mbi: Blocks.mbi()
          }

  @spec new(Blocks.height(), Blocks.mbi()) :: t()
  def new(height, mbi) do
    %__MODULE__{height: height, mbi: mbi}
  end

  @spec execute(t(), AeMdw.Database.transaction()) :: :ok
  def execute(%__MODULE__{height: height, mbi: mbi}, _txn) do
    Sync.Contract.aex9_derive_account_presence!({height, mbi})
  end
end
