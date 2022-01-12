defmodule AeMdw.Db.OracleResponseMutation do
  @moduledoc """
  Processes oracle_response_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Node.Db
  alias AeMdw.Txs

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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        block_index: {height, _mbi},
        txi: txi,
        oracle_pk: oracle_pk,
        fee: fee
      }) do
    IntTransfer.write({height, txi}, "reward_oracle", oracle_pk, txi, fee)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.OracleResponseMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
