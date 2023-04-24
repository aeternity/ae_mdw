defmodule AeMdw.Sync.Transaction do
  @moduledoc """
  Provides transaction ids.
  """
  alias AeMdw.Node

  @spec get_ids_from_tx(Node.signed_tx()) :: [Node.Db.pubkey()]
  def get_ids_from_tx(signed_tx) do
    {tx_type, tx} =
      signed_tx
      |> :aetx_sign.tx()
      |> :aetx.specialize_type()

    tx_type
    |> AeMdw.Node.tx_ids_positions()
    |> Enum.map(&elem(tx, &1))
  end
end
