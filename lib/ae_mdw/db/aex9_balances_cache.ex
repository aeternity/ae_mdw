defmodule AeMdw.Db.Aex9BalancesCache do
  @moduledoc """
  Cache of aex9 balances in order to call the contract a single time for the same block.
  """
  alias AeMdw.Node.Db, as: NodeDb

  alias AeMdw.Blocks
  alias AeMdw.EtsCache

  @typep balances :: %{{:address, NodeDb.pubkey()} => integer()}
  @table :aex9_balances
  @expire_minutes 24 * 60

  @spec init() :: :ok
  def init do
    EtsCache.new(@table, @expire_minutes, :ordered_set)
    :ok
  end

  @spec get(NodeDb.pubkey(), Blocks.block_index(), Blocks.block_hash()) ::
          {:ok, balances()} | :not_found
  def get(contract_pk, block_index, block_hash) do
    case EtsCache.get(@table, {contract_pk, block_index, block_hash}) do
      {balances, _time} -> {:ok, balances}
      nil -> :not_found
    end
  end

  @spec put(NodeDb.pubkey(), Blocks.block_index(), Blocks.block_hash(), balances()) :: :ok
  def put(contract_pk, height, block_hash, balances) do
    EtsCache.put(@table, {contract_pk, height, block_hash}, balances)
    :ok
  end

  @spec purge(NodeDb.pubkey(), Blocks.block_index()) :: :ok
  def purge(contract_pk, block_index) do
    with {^contract_pk, ^block_index, hash} <-
           EtsCache.next(@table, {contract_pk, block_index, <<>>}) do
      EtsCache.del(@table, {contract_pk, block_index, hash})
    end

    :ok
  end
end
