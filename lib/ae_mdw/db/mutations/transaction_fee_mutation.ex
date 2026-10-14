defmodule AeMdw.Db.TransactionFeeMutation do
  @moduledoc """
  Add
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:txi, :tx_hash, :block_index, :time, :fee]

  @typep fee() :: non_neg_integer()

  @opaque t() :: %__MODULE__{
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash(),
            block_index: Blocks.block_index(),
            time: Blocks.time(),
            fee: fee()
          }

  @spec new(Txs.txi(), Txs.tx_hash(), Blocks.block_index(), Blocks.time(), fee()) :: t()
  def new(txi, tx_hash, block_index, mb_time, fee) do
    %__MODULE__{txi: txi, tx_hash: tx_hash, block_index: block_index, time: mb_time, fee: fee}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          txi: txi,
          tx_hash: tx_hash,
          block_index: block_index,
          time: mb_time,
          fee: fee
        },
        state
      ) do
    accumulated_fee =
      case State.get(state, Model.Tx, txi - 1) do
        {:ok, Model.tx(accumulated_fee: accumulated_fee)} -> accumulated_fee + fee
        :not_found -> fee
      end

    m_tx =
      Model.tx(
        index: txi,
        id: tx_hash,
        block_index: block_index,
        time: mb_time,
        fee: fee,
        accumulated_fee: accumulated_fee
      )

    State.put(state, Model.Tx, m_tx)
  end
end
