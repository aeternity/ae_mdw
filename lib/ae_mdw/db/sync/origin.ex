defmodule AeMdw.Db.Sync.Origin do
  @moduledoc """
  Generates a list of Origin related mutations to map a transactions object/pubkey to a txi and inversely too.
  """

  alias AeMdw.Node
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.DatabaseWriteMutation
  alias AeMdw.Db.WriteFieldMutation
  alias AeMdw.Txs

  require Model

  @spec origin_mutations(
          Node.tx_type(),
          WriteFieldMutation.pos(),
          NodeDb.pubkey(),
          Txs.txi(),
          Txs.tx_hash()
        ) :: [Mutation.t()]
  def origin_mutations(tx_type, pos, pubkey, txi, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})

    [
      DatabaseWriteMutation.new(Model.Origin, m_origin),
      DatabaseWriteMutation.new(Model.RevOrigin, m_rev_origin),
      WriteFieldMutation.new(tx_type, pos, pubkey, txi)
    ]
  end
end
