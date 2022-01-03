defmodule AeMdw.Db.WriteFieldMutation do
  @moduledoc """
  Stores the index for the Fields table.
  """

  alias AeMdw.Txs
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Node.Db

  require Model

  defstruct [:tx_type, :pos, :pubkey, :txi]

  @typep tx_type() :: :contract_create_tx
  @typep pos() :: non_neg_integer() | nil

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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{tx_type: tx_type, pos: pos, pubkey: pubkey, txi: txi}) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    Mnesia.write(Model.Field, m_field)
    Model.incr_count({tx_type, pos, pubkey})
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.WriteFieldMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
