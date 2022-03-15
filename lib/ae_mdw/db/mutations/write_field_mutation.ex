defmodule AeMdw.Db.WriteFieldMutation do
  @moduledoc """
  Stores the index for the Fields table.
  """

  alias AeMdw.Txs
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Node.Db
  alias AeMdw.Node
  alias AeMdw.Db.Sync.IdCounter

  require Model

  @derive AeMdw.Db.TxnMutation
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

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{tx_type: tx_type, pos: pos, pubkey: pubkey, txi: txi}, txn) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    Database.write(txn, Model.Field, m_field)
    IdCounter.incr_count(txn, {tx_type, pos, pubkey})
  end
end
