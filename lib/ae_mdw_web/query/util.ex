defmodule AeMdwWeb.Query.Util do
  alias AeMdw.Node, as: AE

  def tx_positions(tx_type) do
    poss = Map.values(AE.tx_ids(tx_type))
    tx_type in [:contract_create_tx, :channel_create_tx, :oracle_register_tx]
    && [nil | poss] # nil - for link
    || poss
  end


end
