defmodule AeMdw.Migrations.RecountAex9Holders do
  @moduledoc """
  Recounts the holders of every AEX-9 contract from its stored balances, the
  way the API used to count them on every request, now that it serves the
  per-contract counter instead. RecomputeAllAex9BalancesFromDryRun only moved
  the counter by the balances it changed, so any drift the counter had
  accumulated was kept.

  That drift is what flagged contracts with an invalid number of holders,
  which hides their balances, so those flags are cleared too.

  Runs before syncing starts, so no block updates a counter while it's being
  rewritten.
  """

  alias AeMdw.Aex9
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Stats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {:ok, recount_holders(state) + clear_invalid_holders_flags(state)}
  end

  defp recount_holders(state) do
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
    |> Enum.reduce(0, fn {contract_pk, count}, updated_count ->
      _state =
        State.put(
          state,
          Model.Stat,
          Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: count)
        )

      updated_count + 1
    end)
  end

  defp clear_invalid_holders_flags(state) do
    invalid_reason = Aex9.invalid_number_of_holders_reason()

    Model.AexnInvalidContract
    |> RocksDbCF.stream(
      key_boundary: Collection.generate_key_boundary({:aex9, Collection.binary()})
    )
    |> Enum.filter(&match?(Model.aexn_invalid_contract(reason: ^invalid_reason), &1))
    |> Enum.reduce(0, fn Model.aexn_invalid_contract(index: index), cleared_count ->
      _state = State.delete(state, Model.AexnInvalidContract, index)

      cleared_count + 1
    end)
  end
end
