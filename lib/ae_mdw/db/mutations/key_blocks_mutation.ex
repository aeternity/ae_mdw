defmodule AeMdw.Db.KeyBlocksMutation do
  @moduledoc """
  Writes key block full model for the current height and next_txi for next height.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Database
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.TxnMutation
  defstruct [:key_block, :next_txi]

  @opaque t() :: %__MODULE__{
            key_block: Database.record(),
            next_txi: Txs.txi()
          }

  @spec new(Database.record(), Txs.txi()) :: t()
  def new(m_block, next_txi) do
    %__MODULE__{key_block: m_block, next_txi: next_txi}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{key_block: m_block, next_txi: next_txi}, state) do
    {height, -1} = Model.block(m_block, :index)
    {:ok, next_kb} = State.get(state, Model.Block, {height + 1, -1})

    state
    |> State.put(Model.Block, m_block)
    |> State.put(Model.Block, Model.block(next_kb, tx_index: next_txi))
  end
end
