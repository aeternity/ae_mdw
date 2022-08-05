defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Db.Aex9BalancesCache
  alias AeMdw.Db.Model
  alias AeMdw.Db.PurgeAex9StateMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.UpdateAex9StateMutation
  alias AeMdw.Log

  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Sync.AsyncStoreServer

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk, block_index, _call_txi] = args) do
    {time_delta, {write_mutation, delete_mutation}} = :timer.tc(fn -> mutations(args) end)

    Log.info("[update_aex9_state] #{enc_ct(contract_pk)} after #{time_delta / @microsecs}s")

    AsyncStoreServer.write_mutations(block_index, [
      delete_mutation,
      write_mutation
    ])

    :ok
  end

  defp mutations([contract_pk, block_index, call_txi]) do
    {balances, purged_balances} = aex9_balances(contract_pk, block_index)

    if map_size(balances) == 0 do
      m_empty_balance = Model.aex9_balance(index: {contract_pk, <<>>})

      {
        WriteMutation.new(Model.Aex9Balance, m_empty_balance),
        purge_mutation(contract_pk, purged_balances)
      }
    else
      balances_list =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      {
        UpdateAex9StateMutation.new(contract_pk, block_index, call_txi, balances_list),
        purge_mutation(contract_pk, purged_balances)
      }
    end
  end

  defp purge_mutation(_pk, purged_balances) when map_size(purged_balances) == 0, do: nil

  defp purge_mutation(contract_pk, purged_balances) do
    accounts_list =
      Enum.map(purged_balances, fn {{:address, account_pk}, _amount} -> account_pk end)

    PurgeAex9StateMutation.new(contract_pk, accounts_list)
  end

  defp aex9_balances(contract_pk, block_index) do
    {type, height, next_hash} = type_height_hash(block_index)

    case Aex9BalancesCache.get(contract_pk, block_index, next_hash) do
      {:ok, balances} ->
        {balances, %{}}

      :not_found ->
        purged_balances = Aex9BalancesCache.purge(contract_pk, block_index)
        {balances, _height_hash} = DBN.aex9_balances(contract_pk, {type, height, next_hash})
        Aex9BalancesCache.put(contract_pk, block_index, next_hash, balances)

        {balances, purged_balances}
    end
  end

  defp type_height_hash({kbi, mbi}) do
    case DBN.get_key_block_hash(kbi + 1) do
      nil ->
        DBN.top_height_hash(true)

      next_kb_hash ->
        next_hash = DBN.get_next_hash(next_kb_hash, mbi)
        {type, height} = if next_hash == next_kb_hash, do: {:key, kbi + 1}, else: {:micro, kbi}

        {type, height, next_hash}
    end
  end

  defp enc_ct(<<pk::binary-32>>), do: :aeser_api_encoder.encode(:contract_pubkey, pk)
  defp enc_ct(invalid_pk), do: invalid_pk
end
