defmodule AeMdw.Db.OracleResponseMutation do
  @moduledoc """
  Processes oracle_response_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  @derive AeMdw.Db.TxnMutation
  defstruct [:block_index, :txi, :oracle_pk, :fee]

  @opaque t() :: %__MODULE__{
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            oracle_pk: Db.pubkey(),
            fee: IntTransfer.amount()
          }

  @spec new(Blocks.block_index(), Txs.txi(), Db.pubkey(), IntTransfer.amount()) :: t()
  def new(block_index, txi, oracle_pk, fee) do
    %__MODULE__{
      block_index: block_index,
      txi: txi,
      oracle_pk: oracle_pk,
      fee: fee
    }
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          block_index: {height, _mbi},
          txi: txi,
          oracle_pk: oracle_pk,
          fee: fee
        },
        txn
      ) do
    IntTransfer.write(txn, {height, txi}, "reward_oracle", oracle_pk, txi, fee)
  end
end
