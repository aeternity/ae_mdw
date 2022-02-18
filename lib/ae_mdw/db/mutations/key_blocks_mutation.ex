defmodule AeMdw.Db.KeyBlocksMutation do
  @moduledoc """
  Writes key block full model for the current height and next_txi for next height.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Txs

  require Model

  defstruct [:key_block, :next_txi]

  @opaque t() :: %__MODULE__{
            key_block: Database.record(),
            next_txi: Txs.txi()
          }

  @spec new(Database.record(), Txs.txi()) :: t()
  def new(m_block, next_txi) do
    %__MODULE__{key_block: m_block, next_txi: next_txi}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{key_block: m_block, next_txi: next_txi}, txn) do
    {height, -1} = Model.block(m_block, :index)
    [next_kb] = Database.read(Model.Block, {height + 1, -1})

    Database.write(txn, Model.Block, m_block)
    Database.write(txn, Model.Block, Model.block(next_kb, tx_index: next_txi))
  end
end

defimpl AeMdw.Db.TxnMutation, for: AeMdw.Db.KeyBlocksMutation do
  def execute(mutation, txn) do
    @for.execute(mutation, txn)
  end
end
