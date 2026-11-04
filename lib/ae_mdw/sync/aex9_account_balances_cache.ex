defmodule AeMdw.Sync.Aex9AccountBalancesCache do
  @moduledoc """
  Cache of single account aex9 balances in order to call the contract a single time for the same account and block.
  """
  alias AeMdw.Node.Db, as: NodeDb

  alias AeMdw.Blocks
  alias AeMdw.EtsCache

  @table :aex9_account_balances
  @expire_minutes 24 * 60

  @spec init() :: :ok
  def init do
    EtsCache.new(@table, @expire_minutes)
    :ok
  end

  @spec get(NodeDb.pubkey(), Blocks.block_index(), Blocks.block_hash(), NodeDb.pubkey()) ::
          {:ok, integer()} | :not_found
  def get(contract_pk, block_index, block_hash, account_pk) do
    case EtsCache.get(@table, {contract_pk, block_index, block_hash, account_pk}) do
      {amount, _time} -> {:ok, amount}
      nil -> :not_found
    end
  end

  @spec put(
          NodeDb.pubkey(),
          Blocks.block_index(),
          Blocks.block_hash(),
          NodeDb.pubkey(),
          integer()
        ) :: :ok
  def put(contract_pk, block_index, block_hash, account_pk, amount) do
    EtsCache.put(@table, {contract_pk, block_index, block_hash, account_pk}, amount)
    :ok
  end
end
