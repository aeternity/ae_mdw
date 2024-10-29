defmodule AeMdw.Db.Sync.InnerTx do
  @moduledoc """
  Returns inner tx when outer is :ga_meta_tx and :payinfo_for_tx.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node
  alias AeMdw.Txs

  require Model

  @spec signed_tx(Txs.wrap_tx_type(), Node.tx()) :: Node.signed_tx()
  def signed_tx(:ga_meta_tx, wrapper_tx), do: :aega_meta_tx.tx(wrapper_tx)
  def signed_tx(:paying_for_tx, wrapper_tx), do: :aec_paying_for_tx.tx(wrapper_tx)

  @spec tx_type_mutation(Node.tx_type(), Txs.txi()) :: WriteMutation.t()
  def tx_type_mutation(inner_type, txi) do
    WriteMutation.new(Model.InnerType, Model.type(index: {inner_type, txi}))
  end
end
