defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "assumes block index is in place, syncs whole history"

  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @log_freq 1000
  @sync_cache_cleanup_freq 150_000

  ################################################################################

  def sync(max_height \\ :safe) do
    max_height = Sync.height((is_integer(max_height) && max_height + 1) || max_height)
    bi_max_kbi = Sync.BlockIndex.sync(max_height) - 1

    case max_txi() do
      nil ->
        sync(0, bi_max_kbi, 0)

      max_txi when is_integer(max_txi) ->
        {tx_kbi, _} = Model.tx(read_tx!(max_txi), :block_index)
        next_txi = max_txi + 1
        from_height = tx_kbi + 1
        sync(from_height, bi_max_kbi, next_txi)
    end
  end

  def sync(from_height, to_height, txi) when from_height <= to_height do
    tracker = Sync.progress_logger(&sync_generation/2, @log_freq, &log_msg/2)
    next_txi = from_height..to_height |> Enum.reduce(txi, tracker)

    :mnesia.transaction(fn ->
      [succ_kb] = :mnesia.read(Model.Block, {to_height + 1, -1})
      :mnesia.write(Model.Block, Model.block(succ_kb, tx_index: next_txi), :write)
    end)

    next_txi
  end

  def sync(from_height, to_height, txi) when from_height > to_height,
    do: txi

  def clear(),
    do: Enum.each(AeMdw.Db.Model.tables(), &:mnesia.clear_table/1)

  def min_txi(), do: txi(&first/1)
  def max_txi(), do: txi(&last/1)

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)

  ################################################################################

  defp sync_generation(height, txi) do
    {key_block, micro_blocks} = AE.Db.get_blocks(height)

    {:atomic, next_txi} =
      :mnesia.transaction(fn ->
        :ets.delete_all_objects(:stat_sync_cache)
        :ets.delete_all_objects(:ct_create_sync_cache)
        :ets.delete_all_objects(:tx_sync_cache)

        Sync.Name.expire(height)
        Sync.Oracle.expire(height - 1)

        kb_txi = (txi == 0 && -1) || txi
        kb_header = :aec_blocks.to_key_header(key_block)
        kb_hash = :aec_headers.hash_header(kb_header) |> ok!
        kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)
        :mnesia.write(Model.Block, kb_model, :write)

        height >= AE.min_block_reward_height() &&
          Sync.IntTransfer.block_rewards(kb_header, kb_hash)

        {next_txi, _mb_index} = micro_blocks |> Enum.reduce({txi, 0}, &sync_micro_block/2)

        Sync.Stat.store(height)
        Sync.Stat.sum_store(height)

        next_txi
      end)

    if rem(height, @sync_cache_cleanup_freq) == 0 do
      :ets.delete_all_objects(:name_sync_cache)
      :ets.delete_all_objects(:oracle_sync_cache)
    end

    next_txi
  end

  defp sync_micro_block(mblock, {txi, mbi}) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_hash = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)) |> ok!
    mb_txi = (txi == 0 && -1) || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    :mnesia.write(Model.Block, mb_model, :write)
    mb_txs = :aec_blocks.txs(mblock)
    events = AeMdw.Contract.get_grouped_events(mblock)
    tx_ctx = {{height, mbi}, mb_time, events}
    next_txi = Enum.reduce(mb_txs, txi, &sync_transaction(&1, &2, tx_ctx))
    Sync.Contract.aex9_derive_account_presence!({height, mbi})

    {next_txi, mbi + 1}
  end

  def sync_transaction(
        signed_tx,
        txi,
        {block_index, mb_time, mb_events} = tx_ctx,
        inner_tx? \\ false
      ) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    hash = :aetx_sign.hash(signed_tx)
    type = mod.type()

    write_tx(type, txi, hash, block_index, mb_time, inner_tx?)
    write_links(type, tx, signed_tx, txi, hash, block_index)

    if type == :contract_call_tx do
      ct_pk = :aect_call_tx.contract_pubkey(tx)
      ct_txi = Sync.Contract.get_txi(ct_pk)
      events = Map.get(mb_events, hash, [])
      Sync.Contract.events(events, txi, ct_txi)
    end

    write_fields(type, tx, block_index, txi)

    if type == :ga_meta_tx or type == :paying_for_tx do
      inner_signed_tx = Sync.InnerTx.signed_tx(type, tx)
      # indexes the inner with the txi from the wrapper/outer
      sync_transaction(inner_signed_tx, txi, tx_ctx, true)
    end

    txi + 1
  end

  #
  # Private functions
  #
  defp write_tx(type, txi, tx_hash, {_kbi, _mbi} = block_index, mb_time, inner_tx?) do
    model_tx = Model.tx(index: txi, id: tx_hash, block_index: block_index, time: mb_time)
    :ets.insert(:tx_sync_cache, {txi, model_tx})

    if not inner_tx? do
      :mnesia.write(Model.Tx, model_tx, :write)
    end

    :mnesia.write(Model.Type, Model.type(index: {type, txi}), :write)
    :mnesia.write(Model.Time, Model.time(index: {mb_time, txi}), :write)
  end

  defp write_links(:contract_create_tx, tx, _signed_tx, txi, tx_hash, bi) do
    pk = :aect_contracts.pubkey(:aect_contracts.new(tx))
    owner_pk = :aect_create_tx.owner_pubkey(tx)
    :ets.insert(:ct_create_sync_cache, {pk, txi})
    write_origin(:contract_create_tx, pk, txi, tx_hash)
    Sync.Contract.create(pk, owner_pk, txi, bi)
  end

  defp write_links(:contract_call_tx, tx, _signed_tx, txi, _tx_hash, bi) do
    pk = :aect_call_tx.contract_pubkey(tx)
    Sync.Contract.call(pk, tx, txi, bi)
  end

  defp write_links(:channel_create_tx, _tx, signed_tx, txi, tx_hash, _bi) do
    {:ok, pk} = :aesc_utils.channel_pubkey(signed_tx)
    write_origin(:channel_create_tx, pk, txi, tx_hash)
  end

  defp write_links(:oracle_register_tx, tx, _signed_tx, txi, tx_hash, bi) do
    pk = :aeo_register_tx.account_pubkey(tx)
    write_origin(:oracle_register_tx, pk, txi, tx_hash)
    Sync.Oracle.register(pk, tx, txi, bi)
  end

  defp write_links(:oracle_extend_tx, tx, _signed_tx, txi, _tx_hash, bi),
    do: Sync.Oracle.extend(:aeo_extend_tx.oracle_pubkey(tx), tx, txi, bi)

  defp write_links(:oracle_response_tx, tx, _signed_tx, txi, _tx_hash, bi),
    do: Sync.Oracle.respond(:aeo_response_tx.oracle_pubkey(tx), tx, txi, bi)

  defp write_links(:name_claim_tx, tx, _signed_tx, txi, tx_hash, bi) do
    plain_name = String.downcase(:aens_claim_tx.name(tx))
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    write_origin(:name_claim_tx, name_hash, txi, tx_hash)
    Sync.Name.claim(plain_name, name_hash, tx, txi, bi)
  end

  defp write_links(:name_update_tx, tx, _signed_tx, txi, _tx_hash, bi),
    do: Sync.Name.update(:aens_update_tx.name_hash(tx), tx, txi, bi)

  defp write_links(:name_transfer_tx, tx, _signed_tx, txi, _tx_hash, bi),
    do: Sync.Name.transfer(:aens_transfer_tx.name_hash(tx), tx, txi, bi)

  defp write_links(:name_revoke_tx, tx, _signed_tx, txi, _tx_hash, bi),
    do: Sync.Name.revoke(:aens_revoke_tx.name_hash(tx), tx, txi, bi)

  defp write_links(_type, _tx, _signed_tx, _txi, _tx_hash, _bi),
    do: :nop

  defp write_origin(tx_type, pubkey, txi, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})
    :mnesia.write(Model.Origin, m_origin, :write)
    :mnesia.write(Model.RevOrigin, m_rev_origin, :write)
    write_field(tx_type, nil, pubkey, txi)
  end

  defp write_fields(tx_type, tx, block_index, txi) do
    tx_type
    |> AE.tx_ids()
    |> Enum.each(fn {field, pos} ->
      <<_::256>> = pk = resolve_pubkey(elem(tx, pos), tx_type, field, block_index)
      write_field(tx_type, pos, pk, txi)
    end)
  end

  defp write_field(tx_type, pos, pubkey, txi) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    :mnesia.write(Model.Field, m_field, :write)
    Model.incr_count({tx_type, pos, pubkey})
  end

  defp resolve_pubkey(id, :spend_tx, :recipient_id, block_index) do
    case :aeser_id.specialize(id) do
      {:name, name_hash} ->
        AeMdw.Db.Name.ptr_resolve!(block_index, name_hash, "account_pubkey")

      {_tag, pk} ->
        pk
    end
  end

  defp resolve_pubkey(id, _type, _field, _block_index) do
    {_tag, pk} = :aeser_id.specialize(id)
    pk
  end

  defp txi(f) do
    case f.(Model.Tx) do
      :"$end_of_table" -> nil
      txi -> txi
    end
  end

  defp kbi(f) do
    case f.(Model.Tx) do
      :"$end_of_table" ->
        nil

      txi ->
        {kbi, _mbi} = Model.tx(read_tx!(txi), :block_index)
        kbi
    end
  end

  defp log_msg(height, _ignore),
    do: "syncing transactions at generation #{height}"
end
