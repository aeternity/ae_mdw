defmodule AeMdw.Migrations.AddAccountCreationTable do
  @moduledoc """
  Add account creation table and update account creation statistics.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Sync.Transaction

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    keys_to_delete = state |> Collection.stream(Model.AccountCreation, nil) |> Enum.to_list()
    clear_mutation = DeleteKeysMutation.new(%{Model.AccountCreation => keys_to_delete})
    state = State.commit_db(state, [clear_mutation])

    protocol_accounts =
      for {protocol, height} <- :aec_hard_forks.protocols(),
          protocol <= :aec_hard_forks.protocol_vsn(:lima),
          {account, _balance} <- :aec_fork_block_settings.accounts(protocol),
          into: %{} do
        {account, height}
      end

    Model.Tx
    |> RocksDbCF.stream()
    |> Task.async_stream(fn Model.tx(id: tx_hash, time: time) ->
      tx_hash
      |> :aec_db.get_signed_tx()
      |> Transaction.get_ids_from_tx()
      |> Enum.reduce(%{}, fn
        {:id, :account, pubkey}, acc ->
          Map.put_new(acc, pubkey, time)

        _other, acc ->
          acc
      end)
    end)
    |> Enum.reduce(protocol_accounts, fn {:ok, new_map}, acc_times ->
      Map.merge(acc_times, new_map, fn _k, v1, v2 ->
        min(v1, v2)
      end)
    end)
    |> Enum.reduce({%{}, []}, fn {pubkey, time}, {statistics, mutations} ->
      new_statistics =
        time
        |> SyncStats.time_intervals()
        |> Enum.map(fn {interval_by, interval_start} ->
          {:total_accounts, interval_by, interval_start}
        end)
        |> Enum.reduce(statistics, fn key, statistics ->
          Map.update(statistics, key, 1, &(&1 + 1))
        end)

      {new_statistics,
       [
         WriteMutation.new(
           Model.AccountCreation,
           Model.account_creation(index: pubkey, creation_time: time)
         )
         | mutations
       ]}
    end)
    |> then(fn {statistics, mutations} ->
      Stream.concat(mutations, [StatisticsMutation.new(statistics)])
    end)
    |> Stream.chunk_every(1000)
    |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
      {
        State.commit_db(acc_state, mutations),
        count + length(mutations)
      }
    end)
    |> then(fn {_state, count} -> {:ok, count} end)
  end
end
