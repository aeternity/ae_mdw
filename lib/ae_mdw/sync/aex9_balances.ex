defmodule AeMdw.Sync.Aex9Balances do
  @moduledoc """
  Cache-through access to aex9 balances.
  """

  alias AeMdw.Db.Contract
  alias AeMdw.Db.PurgeAex9StateMutation
  alias AeMdw.Log
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Sync.Aex9AccountBalancesCache
  alias AeMdw.Sync.Aex9BalancesCache

  @typep pubkey :: NodeDb.pubkey()
  @typep block_index :: AeMdw.Blocks.block_index()
  @typep balances :: [AeMdw.Db.Contract.account_balance()]
  @typep balance_key :: {pubkey(), block_index(), AeMdw.Blocks.block_hash(), pubkey()}

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

  # Runs the get_balance/4 dry-runs of the calls' aex9 events concurrently, so
  # that executing the calls finds the balances cached. What fails here isn't
  # cached and get_balance/4 runs it again. Returns the keys it cached.
  @spec prefetch_balances([{block_index(), [AeMdw.Contract.call()]}], pos_integer()) ::
          [balance_key()]
  def prefetch_balances(blocks_call_recs, concurrency) do
    blocks_call_recs
    |> concurrently(concurrency, &uncached_balances/1)
    |> Enum.concat()
    |> concurrently(concurrency, &prefetch_balance/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec delete_prefetched([balance_key()]) :: :ok
  def delete_prefetched(keys) do
    Enum.each(keys, fn {contract_pk, block_index, block_hash, account_pk} ->
      Aex9AccountBalancesCache.delete(contract_pk, block_index, block_hash, account_pk)
    end)
  end

  defp uncached_balances({block_index, call_recs}) do
    case call_recs |> Enum.flat_map(&Contract.aex9_balance_accounts/1) |> Enum.uniq() do
      [] ->
        []

      accounts ->
        {_type, _height, next_hash} = height_hash = type_height_hash(block_index)

        for {contract_pk, account_pk} <- accounts,
            Aex9AccountBalancesCache.get(contract_pk, block_index, next_hash, account_pk) ==
              :not_found,
            do: {contract_pk, account_pk, block_index, height_hash}
    end
  end

  defp prefetch_balance({contract_pk, account_pk, block_index, height_hash}) do
    {_type, _height, next_hash} = height_hash

    case get_balance(contract_pk, account_pk, block_index, height_hash) do
      {:ok, _amount} -> {contract_pk, block_index, next_hash, account_pk}
      {:error, _reason} -> nil
    end
  end

  # leaves out the items that fun fails on
  defp concurrently(items, concurrency, fun) do
    items
    |> Task.async_stream(&catch_failure(fun, &1),
      max_concurrency: concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, results} -> results end)
  end

  defp catch_failure(fun, item) do
    [fun.(item)]
  catch
    kind, reason ->
      Log.warn("[prefetch_balances] #{Exception.format_banner(kind, reason)}")
      []
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
