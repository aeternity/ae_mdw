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
  alias AeMdw.Sync.Supervisor, as: SyncSup

  require Model
  require Ex2ms

  @fortuna_txi_begin 2129380

  @doc """
  Reindex tx_index for inner transactions after 90800 block when Fortuna upgrade introduced Generalized Accounts.
  """
  @spec run() :: {:ok, {pos_integer(), pos_integer()}}
  def run do
    begin = DateTime.utc_now()

    if :ok != Application.ensure_started(:ae_mdw) do
      IO.puts("Ensure sync tables...")
      SyncSup.init_tables()
      MdwApp.init(:contract_cache)
      MdwApp.init(:db_state)
    end

    ga_meta_txis = lookup_txis(:ga_meta_tx)
    paying_for_txis = lookup_txis(:paying_for_tx)

    txi_list = Enum.sort(ga_meta_txis ++ paying_for_txis)
    last_txi = Util.last(Model.Tx)
    indexed_count = reindex_txs(txi_list, last_txi) - last_txi

    duration = DateTime.diff(DateTime.utc_now(), begin)
    IO.puts("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp reindex_txs(wrapper_txi_list, last_txi) do
    wrapper_txi_list
    |> Enum.reduce(last_txi + 1, fn wrapper_txi, next_txi ->
      m_tx = Util.read_tx!(wrapper_txi)
      {tx_kbi, _} = Model.tx(m_tx, :block_index)
      wrapper_tx_id = Model.tx(m_tx, :id)

      sync_generation_inner_txs(tx_kbi, next_txi, wrapper_tx_id)
    end)
  end

  defp sync_generation_inner_txs(height, next_txi, wrapper_tx_id) do
    {:atomic, {next_txi, _mbi}} =
      :mnesia.transaction(fn ->
        :ets.delete_all_objects(:ct_create_sync_cache)
        :ets.delete_all_objects(:tx_sync_cache)

        height
        |> AE.Db.get_micro_blocks()
        |> Enum.reduce({next_txi, 0}, &sync_micro_block_inner_txs(&1, &2, wrapper_tx_id))
      end)

    next_txi
  end

  defp sync_micro_block_inner_txs(mblock, {txi, mbi}, wrapper_tx_id) do
    tx_ctx = tx_context(mblock, mbi)

    new_txi =
      mblock
      |> :aec_blocks.txs()
      |> Enum.filter(fn wrapper_tx ->
        {tx_type, _raw_tx} = aetx_specialize_type(wrapper_tx)
        tx_type == :ga_meta_tx or tx_type == :paying_for_tx
      end)
      |> Enum.reduce(txi, fn wrapper_tx, txi ->
        {tx_type, raw_outer_tx} = aetx_specialize_type(wrapper_tx)

        tx_type
        |> SyncInnerTx.signed_tx(raw_outer_tx)
        |> SyncTx.sync_transaction(txi, tx_ctx, wrapper_tx_id)
      end)

    {new_txi, mbi + 1}
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
