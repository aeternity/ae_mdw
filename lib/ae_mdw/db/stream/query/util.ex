defmodule AeMdw.Db.Stream.Query.Util do
  alias AeMdw.Node, as: AE

  @create_tx_types [:contract_create_tx, :channel_create_tx, :oracle_register_tx, :name_claim_tx]

  def tx_positions(tx_type) do
    poss = Map.values(AE.tx_ids(tx_type))
    # nil - for link
    (tx_type in @create_tx_types && [nil | poss]) || poss
  end
end
