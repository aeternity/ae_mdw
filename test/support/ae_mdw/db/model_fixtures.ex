defmodule AeMdw.Db.ModelFixtures do
  @moduledoc false

  alias AeMdw.Db.Model
  alias AeMdw.Blocks
  alias AeMdw.Txs

  require Model

  @spec new_txi() :: Txs.txi()
  def new_txi, do: :ets.update_counter(:counters, :txi, {2, 1})

  @spec new_kbi() :: Blocks.height()
  def new_kbi, do: :ets.update_counter(:counters, :kbi, {2, 1})

  @spec new_block() :: Model.block()
  def new_block do
    Model.block(
      index: {new_kbi(), -1},
      tx_index: Enum.random(1..1_000_000),
      hash: :crypto.strong_rand_bytes(32)
    )
  end

  @spec new_name() :: String.t()
  def new_name, do: "name-#{System.unique_integer([:positive])}.chain"

  @spec new_hash() :: <<_::256>>
  def new_hash, do: :crypto.strong_rand_bytes(32)
end
