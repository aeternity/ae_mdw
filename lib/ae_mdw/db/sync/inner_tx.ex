defmodule AeMdw.Db.Sync.InnerTx do
  @moduledoc """
  Returns inner tx when outer is :ga_meta_tx and :payinfo_for_tx.
  """

  alias AeMdw.Node

  @typep wrapper_type() :: :ga_meta_tx | :paying_for_tx

  @spec signed_tx(wrapper_type(), Node.tx()) :: Node.signed_tx()
  def signed_tx(:ga_meta_tx, wrapper_tx), do: :aega_meta_tx.tx(wrapper_tx)
  def signed_tx(:paying_for_tx, wrapper_tx), do: :aec_paying_for_tx.tx(wrapper_tx)
end
