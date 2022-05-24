defmodule AeMdw.Migrations.UpdateAex9WithLogs do
  @moduledoc """
  Update aex9 balance and presence for contracts in event logs other than those called at :contract_call_tx.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    aex9_log_txis =
      Model.ContractLog
      |> Database.all_keys()
      |> Enum.flat_map(fn key ->
        Model.contract_log(index: {_create_txi, txi, _evt_hash, _i}, ext_contract: addr) =
          Database.fetch!(Model.ContractLog, key)

        if addr != nil and AeMdw.Contract.is_aex9?(addr) do
          [{addr, txi}]
        else
          []
        end
      end)

    Enum.each(aex9_log_txis, fn {contract_pk, txi} ->
      Model.tx(block_index: block_index) = Database.fetch!(Model.Tx, txi)
      Contract.update_aex9_state(State.new(), contract_pk, block_index, txi)
    end)

    AsyncTasks.Producer.commit_enqueued()

    indexed_count = length(aex9_log_txis)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
