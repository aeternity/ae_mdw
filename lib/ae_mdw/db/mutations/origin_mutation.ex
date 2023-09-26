defmodule AeMdw.Db.OriginMutation do
  @moduledoc """
  It maps a transactions object/pubkey to a txi and inversely too.
  """

  alias AeMdw.Db.Sync.ObjectKeys
  alias AeMdw.Node
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteFieldMutation
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:tx_type, :pubkey, :txi, :tx_hash]

  @opaque t() :: %__MODULE__{
            tx_type: Node.tx_type(),
            pubkey: NodeDb.pubkey(),
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash()
          }

  @create_contract_tx_types ~w(contract_create_tx contract_call_tx ga_attach_tx)a

  @spec new(
          Node.tx_type(),
          NodeDb.pubkey(),
          Txs.txi(),
          Txs.tx_hash()
        ) :: t()
  def new(tx_type, pubkey, txi, tx_hash) do
    %__MODULE__{tx_type: tx_type, pubkey: pubkey, txi: txi, tx_hash: tx_hash}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{tx_type: tx_type, pubkey: pubkey, txi: txi, tx_hash: tx_hash},
        state
      ) do
    if tx_type in @create_contract_tx_types do
      ObjectKeys.put_contract(state, pubkey)
    end

    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})

    state
    |> State.put(Model.Origin, m_origin)
    |> State.put(Model.RevOrigin, m_rev_origin)
    |> then(fn state ->
      tx_type
      |> WriteFieldMutation.new(nil, pubkey, txi)
      |> WriteFieldMutation.execute(state)
    end)
  end
end
