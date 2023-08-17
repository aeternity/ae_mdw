defmodule AeMdw.Db.WriteFieldMutation do
  @moduledoc """
  Stores the index for the Fields table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.IdCounter
  alias AeMdw.Node.Db
  alias AeMdw.Node
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:tx_type, :pos, :pubkey, :txi]

  @type pos() :: non_neg_integer() | nil
  @typep tx_type() :: Node.tx_type()

  @opaque t() :: %__MODULE__{
            tx_type: tx_type(),
            pos: pos(),
            pubkey: Db.pubkey(),
            txi: Txs.txi()
          }

  @spec new(tx_type(), pos(), Db.pubkey(), Txs.txi()) :: t()
  def new(tx_type, pos, pubkey, txi) do
    %__MODULE__{tx_type: tx_type, pos: pos, pubkey: pubkey, txi: txi}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{tx_type: tx_type, pos: pos, pubkey: pubkey, txi: txi}, state) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})

    state
    |> State.put(Model.Field, m_field)
    |> IdCounter.incr_count(tx_type, pos, pubkey, false)
  end
end
