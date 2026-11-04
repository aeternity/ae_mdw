defmodule AeMdw.Sync.Aex9Balances do
  @moduledoc """
  Cache-through access to aex9 balances.
  """

  alias AeMdw.Db.PurgeAex9StateMutation
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Sync.Aex9AccountBalancesCache
  alias AeMdw.Sync.Aex9BalancesCache

  @typep pubkey :: NodeDb.pubkey()
  @typep block_index :: AeMdw.Blocks.block_index()
  @typep balances :: [AeMdw.Db.Contract.account_balance()]

  @spec get_balances(pubkey(), block_index()) ::
          {:ok, balances(), balances()}
          | {:error, AeMdw.DryRun.Runner.call_error()}
  def get_balances(contract_pk, block_index),
    do: get_balances(contract_pk, block_index, type_height_hash(block_index))

  @spec get_balances(pubkey(), block_index(), NodeDb.height_hash()) ::
          {:ok, balances(), balances()}
          | {:error, AeMdw.DryRun.Runner.call_error()}
  def get_balances(contract_pk, block_index, {type, height, next_hash}) do
    case Aex9BalancesCache.get(contract_pk, block_index, next_hash) do
      {:ok, dry_run_balances} ->
        {:ok, decode_balances(dry_run_balances), []}

      :not_found ->
        purged_balances =
          contract_pk
          |> Aex9BalancesCache.purge(block_index)
          |> Enum.map(fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

        with {:ok, balances} <- NodeDb.aex9_balances(contract_pk, {type, height, next_hash}) do
          Aex9BalancesCache.put(contract_pk, block_index, next_hash, balances)

          {:ok, decode_balances(balances), purged_balances}
        end
    end
  end

  @spec get_balance(pubkey(), pubkey(), block_index(), NodeDb.height_hash()) ::
          {:ok, integer()} | {:error, AeMdw.DryRun.Runner.call_error()}
  def get_balance(
        contract_pk,
        account_pk,
        block_index,
        {_type, _height, next_hash} = height_hash
      ) do
    case Aex9AccountBalancesCache.get(contract_pk, block_index, next_hash, account_pk) do
      {:ok, amount} ->
        {:ok, amount}

      :not_found ->
        with {:ok, {amount_or_nil, _height_hash}} <-
               NodeDb.aex9_balance(contract_pk, account_pk, height_hash) do
          # balance() returns None for an account the contract never credited
          amount = amount_or_nil || 0
          Aex9AccountBalancesCache.put(contract_pk, block_index, next_hash, account_pk, amount)

          {:ok, amount}
        end
    end
  end

  @spec purge_mutation(pubkey(), balances()) :: nil | PurgeAex9StateMutation.t()
  def purge_mutation(_pk, []), do: nil

  def purge_mutation(contract_pk, purged_balances) do
    accounts_list = Enum.map(purged_balances, fn {account_pk, _amount} -> account_pk end)

    PurgeAex9StateMutation.new(contract_pk, accounts_list)
  end

  @spec type_height_hash(block_index()) :: NodeDb.height_hash()
  def type_height_hash({kbi, mbi}) do
    case NodeDb.get_key_block_hash(kbi + 1) do
      nil ->
        NodeDb.top_height_hash(true)

      next_kb_hash ->
        next_hash = NodeDb.get_next_hash(next_kb_hash, mbi)
        {type, height} = if next_hash == next_kb_hash, do: {:key, kbi + 1}, else: {:micro, kbi}

        {type, height, next_hash}
    end
  end

  defp decode_balances(dry_run_balances) do
    Enum.map(dry_run_balances, fn {{:address, account_pk}, amount} ->
      {account_pk, amount}
    end)
  end
end
