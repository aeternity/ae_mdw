defmodule AeMdw.Db.OriginMutation do
  @moduledoc """
  Creates the records needed to find the contract's origin.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  defstruct [:tx_type, :pubkey, :txi, :tx_hash]

  @typep tx_type() :: :contract_create_tx
  @opaque t() :: %__MODULE__{
            tx_type: tx_type(),
            pubkey: Db.pubkey(),
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash()
          }

  @spec new(tx_type(), Db.pubkey(), Txs.txi(), Txs.tx_hash()) :: t()
  def new(tx_type, pubkey, txi, tx_hash) do
    %__MODULE__{tx_type: tx_type, pubkey: pubkey, txi: txi, tx_hash: tx_hash}
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{tx_type: tx_type, pubkey: pubkey, txi: txi, tx_hash: tx_hash}) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})
    Mnesia.write(Model.Origin, m_origin)
    Mnesia.write(Model.RevOrigin, m_rev_origin)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.OriginMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
