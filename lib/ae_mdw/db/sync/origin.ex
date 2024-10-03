defmodule AeMdw.Db.Sync.Origin do
  @moduledoc """
  Generates a list of Origin related mutations to map a transactions object/pubkey to a txi and inversely too.
  """

  alias AeMdw.Node
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.WriteFieldMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Txs

  require Model

  @spec origin_mutations(
          Node.tx_type(),
          WriteFieldMutation.pos(),
          NodeDb.pubkey(),
          Txs.txi_idx(),
          Txs.tx_hash()
        ) :: [Mutation.t()]
  def origin_mutations(tx_type, pos, pubkey, {txi, _idx} = txi_idx, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi_idx}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi_idx, tx_type, pubkey})

    [
      WriteMutation.new(Model.Origin, m_origin),
      WriteMutation.new(Model.RevOrigin, m_rev_origin),
      WriteFieldMutation.new(tx_type, pos, pubkey, txi)
    ]
  end
end
