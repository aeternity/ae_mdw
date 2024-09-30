defmodule AeMdw.Migrations.AddAccountCreationTable do
  @moduledoc """
    Add account creation table and update account creation statistics.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.TempStore
  alias AeMdw.Db.Sync.Stats, as: SyncStats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    keys_to_delete = state |> Collection.stream(Model.AccountCreation, nil) |> Enum.to_list()
    clear_mutation = DeleteKeysMutation.new(%{Model.AccountCreation => keys_to_delete})
    state = State.commit(state, [clear_mutation])

    protocol_accounts =
      for {protocol, height} <- :aec_hard_forks.protocols(),
          protocol <= :aec_hard_forks.protocol_vsn(:lima),
          {account, _balance} <- :aec_fork_block_settings.accounts(protocol),
          into: %{} do
        {account, height}
      end

    {_state, created} =
      state
      |> Collection.stream(Model.Tx, nil)
      |> Enum.reduce(protocol_accounts, fn txi, acc_times ->
        Model.tx(id: tx_hash, time: time) = State.fetch!(State.mem_state(), Model.Tx, txi)
        {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)

        signed_tx
        |> AeMdw.Sync.Transaction.get_ids_from_tx()
        |> Enum.reduce(acc_times, fn
          {:id, :account, pubkey}, acc ->
            Map.put_new(acc, pubkey, time)

          _other, acc ->
            acc
        end)
      end)
      |> Enum.reduce({State.new(TempStore.new()), []}, fn {pubkey, time}, {state, mutations} ->
        {SyncStats.increment_statistics(state, :total_accounts, time, 1),
         [
           WriteMutation.new(
             Model.AccountCreation,
             Model.account_creation(index: pubkey, creation_time: time)
           )
           | mutations
         ]}
      end)
      |> then(fn {state, mutations} ->
        mutations ++ (state.store |> TempStore.to_mutations() |> Enum.to_list())
      end)
      |> Enum.chunk_every(1000)
      |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
        {
          State.commit_db(acc_state, mutations),
          count + length(mutations)
        }
      end)

    {:ok, created}
  end
end
