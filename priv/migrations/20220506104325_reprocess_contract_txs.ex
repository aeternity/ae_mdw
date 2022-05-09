defmodule AeMdw.Migrations.ReprocessContractTxs do
  @moduledoc """
  Reprocess contract transactions to include fixes and improvements from 1.7.2 to 1.9.0.

  ** This migration might take days to complete. **

  It starts from the block of first aex9 creation which is 170177 for testnet and 171871 for mainnet
  until the last key block. As usual, sync will be paused until the migration is finished.
  """

  alias AeMdw.Database
  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    indexed_count =
      with {:ok, {last_kbi, _mbi}} <- Database.last_key(Model.Block),
           {:ok, {first_txi, _name, _symbol, _decimals}} <-
             Database.first_key(Model.RevAex9Contract),
           {:ok, Model.tx(block_index: {first_kbi, _mbi})} <- Database.fetch(Model.Tx, first_txi) do
        do_migrate(first_kbi..last_kbi)
      else
        :none -> 0
        :not_found -> 0
      end

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp do_migrate(%Range{} = height_range) do
    height_range
    |> Stream.map(fn height ->
      Log.info("Getting mutations for height #{height}...")

      tx_mutations =
        height
        |> read_txs_and_events()
        |> Enum.map(&transaction_mutations/1)
        |> List.flatten()

      [tx_mutations | stats_mutations(height, tx_mutations)]
    end)
    |> Stream.chunk_every(10_000)
    |> Stream.map(fn mutations ->
      State.commit(State.new(), mutations)
      AsyncTasks.Producer.commit_enqueued()

      length(mutations)
    end)
    |> Enum.sum()
  end

  defp read_txs_and_events(height) do
    Model.block(hash: kb_hash, tx_index: continue_txi) =
      Database.fetch!(Model.Block, {height, -1})

    Model.block(hash: next_kb_hash) = Database.fetch!(Model.Block, {height + 1, -1})
    {_key_block, micro_blocks} = AeMdw.Node.Db.get_blocks(kb_hash, next_kb_hash)

    {txs_per_mb, _next_txi} =
      micro_blocks
      |> Enum.with_index()
      |> Enum.reduce({[], continue_txi}, fn {mblock, mbi}, {acc, next_txi} ->
        txs_with_txi =
          mblock
          |> :aec_blocks.txs()
          |> Enum.with_index()
          |> Enum.map(fn {tx, index} -> {tx, index + next_txi} end)

        {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))

        txs_per_mb = %{
          block_index: {height, mbi},
          block_hash: mb_hash,
          mb_time: :aec_blocks.time_in_msecs(mblock),
          mb_events: AeMdw.Contract.get_grouped_events(mblock),
          txs_with_txi: txs_with_txi
        }

        {[txs_per_mb | acc], next_txi + length(:aec_blocks.txs(mblock))}
      end)

    txs_per_mb
    |> Enum.filter(fn %{txs_with_txi: txs_with_txi} -> has_contract_tx?(txs_with_txi) end)
    |> Enum.sort_by(fn %{block_index: bi} -> bi end)
  end

  defp has_contract_tx?(txs_with_txi) do
    Enum.any?(txs_with_txi, fn {signed_tx, _txi} ->
      {mod, _tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
      mod.type() in [:contract_call_tx, :contract_create_tx]
    end)
  end

  defp transaction_mutations(%{
         block_index: block_index,
         block_hash: block_hash,
         mb_time: mb_time,
         mb_events: mb_events,
         txs_with_txi: txs_with_txi
       }) do
    Enum.map(txs_with_txi, fn {signed_tx, txi} ->
      Sync.Transaction.transaction_mutations(
        signed_tx,
        txi,
        {block_index, block_hash, mb_time, mb_events}
      )
    end)
  end

  defp stats_mutations(height, tx_mutations) do
    contracts_created =
      Enum.count(tx_mutations, fn
        %ContractCreateMutation{} -> true
        _other -> false
      end)

    if contracts_created == 0 do
      []
    else
      m_delta_stat = Database.fetch!(Model.DeltaStat, height)

      Model.total_stat(contracts: prev_contracts_count) =
        m_total_stat = Database.fetch!(Model.TotalStat, height - 1)

      m_delta_stat = Model.delta_stat(m_delta_stat, contracts_created: contracts_created)

      m_total_stat =
        Model.total_stat(m_total_stat, contracts: prev_contracts_count + contracts_created)

      [
        WriteMutation.new(Model.DeltaStat, m_delta_stat),
        WriteMutation.new(Model.TotalStat, m_total_stat)
      ]
    end
  end
end
