defmodule AeMdw.Migrations.IndexGaAttachTxs do
  @moduledoc """
  Indexes ga_attach transactions in a way that can be filtered
  with `/txs` using `contract` or `contract_id` params.
  """
  alias AeMdw.Application, as: MdwApp
  alias AeMdw.Node, as: AE

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Log
  alias AeMdw.Database
  alias AeMdw.Sync.Supervisor, as: SyncSup

  require Model
  require Ex2ms
  require Logger

  @fortuna_txi_begin 2_129_380

  @doc """
  Reindexes ga_attach_tx transactions and updates stats with contracts count.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), pos_integer()}} | {:error, :count_mismatch}
  def run(from_startup?) do
    begin = DateTime.utc_now()

    if not from_startup? and :ok != Application.ensure_started(:ae_mdw) do
      Log.info("Ensure sync tables...")
      SyncSup.init_tables()
      MdwApp.init_public(:contract_cache)
      MdwApp.init_public(:db_state)
    end

    txs_found = lookup_txs()
    indexed_count = reindex_txs(txs_found)

    if indexed_count == length(txs_found) do
      duration = DateTime.diff(DateTime.utc_now(), begin)
      Log.info("Indexed #{indexed_count} records in #{duration}s")

      {:ok, {indexed_count, duration}}
    else
      {:error, :count_mismatch}
    end
  end

  defp lookup_txs() do
    txi_spec =
      Ex2ms.fun do
        Model.type(index: {:ga_attach_tx, txi}) when txi >= @fortuna_txi_begin -> txi
      end

    {:atomic, txi_list} =
      :mnesia.transaction(fn ->
        :mnesia.select(Model.Type, txi_spec, :read)
      end)

    Log.info("Found #{length(txi_list)} :ga_attach_tx(s)...")

    {:atomic, bi_txs_list} =
      :mnesia.transaction(fn ->
        Enum.map(txi_list, fn txi ->
          [Model.tx(id: hash, block_index: bi)] = Database.read(Model.Tx, txi)
          {bi, hash, txi}
        end)
      end)

    Log.info("Found #{length(bi_txs_list)} :ga_attach_tx(s)...")

    bi_txs_list
  end

  defp reindex_txs(bi_txs_list) do
    bi_txs_list
    |> Enum.group_by(fn {{height, _mbi}, _tx_hash, _txi} -> height end)
    |> Enum.map(&sync_generation_gaattach_txs/1)
    |> Enum.sum()
  end

  defp sync_generation_gaattach_txs({height, bi_txs_list}) do
    txs_mutations =
      height
      |> AE.Db.get_micro_blocks()
      |> Enum.with_index()
      |> Enum.filter(fn {_mblock, mbi} ->
        Enum.any?(bi_txs_list, fn {{_height, tx_mbi}, _tx_hash, _txi} ->
          tx_mbi == mbi
        end)
      end)
      |> Enum.flat_map(fn {mblock, mbi} ->
        hash_to_txi = Enum.into(bi_txs_list, %{}, fn {_bi, tx_hash, txi} -> {tx_hash, txi} end)

        mblock
        |> :aec_blocks.txs()
        |> Enum.filter(fn signed_tx ->
          hash = :aetx_sign.hash(signed_tx)
          Map.has_key?(hash_to_txi, hash)
        end)
        |> Enum.map(fn signed_tx ->
          hash = :aetx_sign.hash(signed_tx)
          txi = Map.get(hash_to_txi, hash)
          {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))
          mb_time = :aec_blocks.time_in_msecs(mblock)
          tx_ctx = {{height, mbi}, mb_hash, mb_time, %{}}

          Transaction.transaction_mutations({signed_tx, txi}, tx_ctx)
        end)
      end)

    Database.transaction(txs_mutations)

    new_contracts_count = length(txs_mutations)

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        [Model.stat(contracts: contracts) = m_stat] = Database.read(Model.Stat, height + 1)
        new_m_stat = Model.stat(m_stat, contracts: contracts + new_contracts_count)
        Database.write(Model.Stat, new_m_stat)
      end)

    new_contracts_count
  end
end
