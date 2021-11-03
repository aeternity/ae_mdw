defmodule AeMdw.Migrations.IndexInnerTxs do
  @moduledoc """
  Indexes inner transactions as first-class citizens, i.e the same searches on outer transactions
  are possible with inner ones.
  """
  alias AeMdw.Application, as: MdwApp
  alias AeMdw.Node, as: AE

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Db.Sync.InnerTx, as: SyncInnerTx
  alias AeMdw.Db.Sync.Transaction, as: SyncTx
  alias AeMdw.Log
  alias AeMdw.Sync.Supervisor, as: SyncSup

  require Model
  require Ex2ms
  require Logger

  @fortuna_txi_begin 2129380

  @doc """
  Reindex tx_index for inner transactions after 90800 block when Fortuna upgrade introduced Generalized Accounts.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), pos_integer()}}
  def run(from_startup?) do
    begin = DateTime.utc_now()

    if not from_startup? and :ok != Application.ensure_started(:ae_mdw) do
      Log.info("Ensure sync tables...")
      SyncSup.init_tables()
      MdwApp.init_public(:contract_cache)
      MdwApp.init_public(:db_state)
    end

    ga_meta_txis = lookup_txis(:ga_meta_tx)
    paying_for_txis = lookup_txis(:paying_for_tx)

    txi_list = Enum.sort(ga_meta_txis ++ paying_for_txis)
    indexed_count = reindex_txs(txi_list)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp reindex_txs(wrapper_txi_list) do
    wrapper_txi_list
    |> Enum.reduce(0, fn wrapper_txi, acc ->
      m_tx = Util.read_tx!(wrapper_txi)
      {tx_kbi, _} = Model.tx(m_tx, :block_index)

      acc + sync_generation_inner_txs(tx_kbi, wrapper_txi)
    end)
  end

  defp sync_generation_inner_txs(height, wrapper_txi) do
    {:atomic, {_mbi, count}} =
      :mnesia.transaction(fn ->
        :ets.delete_all_objects(:ct_create_sync_cache)
        :ets.delete_all_objects(:tx_sync_cache)

        height
        |> AE.Db.get_micro_blocks()
        |> Enum.reduce({0, 0}, fn mblock, {mbi, acc} ->
          count = sync_micro_block_inner_txs(mblock, mbi, wrapper_txi)
          {mbi + 1, acc + count}
        end)
      end)

    count
  end

  defp sync_micro_block_inner_txs(mblock, mbi, wrapper_txi) do
    tx_ctx = tx_context(mblock, mbi)

    mblock
    |> :aec_blocks.txs()
    |> Enum.filter(fn wrapper_tx ->
      {tx_type, _raw_tx} = aetx_specialize_type(wrapper_tx)
      tx_type == :ga_meta_tx or tx_type == :paying_for_tx
    end)
    |> Enum.reduce(0, fn wrapper_tx, acc ->
      {tx_type, raw_tx} = aetx_specialize_type(wrapper_tx)

      tx_type
      |> SyncInnerTx.signed_tx(raw_tx)
      |> SyncTx.sync_transaction(wrapper_txi, tx_ctx, true)
      acc + 1
    end)
  end

  defp lookup_txis(type) do
    txi_spec =
      Ex2ms.fun do
        {:type, {^type, txi}, nil} when txi >= @fortuna_txi_begin -> txi
      end

    txi_list = Util.select(Model.Type, txi_spec)
    IO.puts("Found #{length(txi_list)} #{type}s...")
    txi_list
  end

  defp aetx_specialize_type(signed_tx), do: signed_tx |> :aetx_sign.tx() |> :aetx.specialize_type()

  defp tx_context(mblock, mbi) do
    block_index = {:aec_blocks.height(mblock), mbi}
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_events = Contract.get_grouped_events(mblock)

    {block_index, mb_time, mb_events}
  end
end
