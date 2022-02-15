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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{key_block: m_block, next_txi: next_txi}) do
    {height, -1} = Model.block(m_block, :index)
    [next_kb] = Database.read(Model.Block, {height + 1, -1})

    Database.write(Model.Block, m_block)
    Database.write(Model.Block, Model.block(next_kb, tx_index: next_txi))
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.KeyBlocksMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
