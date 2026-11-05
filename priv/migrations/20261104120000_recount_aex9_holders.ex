defmodule AeMdw.Migrations.RecountAex9Holders do
  @moduledoc """
  Recounts the holders of every AEX-9 contract from its stored balances, the
  way the API used to count them on every request, now that it serves the
  per-contract counter instead. RecomputeAllAex9BalancesFromDryRun only moved
  the counter by the balances it changed, so any drift the counter had
  accumulated was kept.

  That drift is what flagged contracts with an invalid number of holders,
  which hides their balances, so those flags are cleared too.

  When started with the node it runs in the background while syncing. It only
  reads the balances to find the counters that are off, and hands those
  contracts to the sync commit, which recounts them serialized with the blocks
  that update the same counters. The migration is recorded once they did. A
  counter that already drifted can be missed if a block changed it by exactly
  that drift while the balances were being read.
  """

  alias AeMdw.Aex9
  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.RecountAex9HoldersMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncStoreServer

  require Model

  # the commit waits for the recounts of a chunk while holding the syncing, see AsyncStoreServer
  @chunk_size 50

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()} | {:async, [fun()]}
  def run(state, true = _from_start?) do
    if Application.fetch_env!(:ae_mdw, :sync) do
      {:async, [fn -> flush_recounts(contracts_to_recount()) end]}
    else
      {:ok, recount(state)}
    end
  end

  def run(state, false = _from_start?), do: {:ok, recount(state)}

  defp recount(state) do
    contracts = contracts_to_recount()

    contracts
    |> Enum.flat_map(&recount_mutations/1)
    |> Enum.each(&Mutation.execute(&1, state))

    length(contracts)
  end

  defp flush_recounts(contracts) do
    contracts
    |> Enum.chunk_every(@chunk_size)
    |> Enum.each(fn chunk ->
      chunk
      |> Enum.flat_map(&recount_mutations/1)
      |> AsyncStoreServer.flush_mutations()
    end)
  end

  defp recount_mutations({contract_pk, invalid_holders?}) do
    recount = RecountAex9HoldersMutation.new(contract_pk)

    if invalid_holders? do
      [recount, DeleteKeysMutation.new(%{Model.AexnInvalidContract => [{:aex9, contract_pk}]})]
    else
      [recount]
    end
  end

  defp contracts_to_recount do
    invalid_holders = invalid_holders_contracts()

    drifted_contracts()
    |> MapSet.new()
    |> MapSet.union(invalid_holders)
    |> Enum.map(&{&1, MapSet.member?(invalid_holders, &1)})
  end

  defp drifted_contracts do
    holders_counts =
      Model.Aex9EventBalance
      |> RocksDbCF.stream()
      |> Enum.reduce(%{}, fn
        Model.aex9_event_balance(index: {contract_pk, account_pk}, amount: amount), counts
        when account_pk != <<>> and is_integer(amount) and amount > 0 ->
          Map.update(counts, contract_pk, 1, &(&1 + 1))

        _balance, counts ->
          counts
      end)

    stored_counts =
      Model.Stat
      |> RocksDbCF.stream(
        key_boundary: Collection.generate_key_boundary({:aex9_holder_count, Collection.binary()})
      )
      |> Map.new(fn Model.stat(index: {:aex9_holder_count, contract_pk}, payload: count) ->
        {contract_pk, count}
      end)

    stored_counts
    |> Map.new(fn {contract_pk, _count} -> {contract_pk, 0} end)
    |> Map.merge(holders_counts)
    |> Enum.reject(fn {contract_pk, count} -> Map.get(stored_counts, contract_pk) == count end)
    |> Enum.map(fn {contract_pk, _count} -> contract_pk end)
  end

  defp invalid_holders_contracts do
    invalid_reason = Aex9.invalid_number_of_holders_reason()

    Model.AexnInvalidContract
    |> RocksDbCF.stream(
      key_boundary: Collection.generate_key_boundary({:aex9, Collection.binary()})
    )
    |> Enum.filter(&match?(Model.aexn_invalid_contract(reason: ^invalid_reason), &1))
    |> MapSet.new(fn Model.aexn_invalid_contract(index: {:aex9, contract_pk}) -> contract_pk end)
  end
end
