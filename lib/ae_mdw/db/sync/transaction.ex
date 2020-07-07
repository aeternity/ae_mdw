defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "assumes block index is in place, syncs whole history"

  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync

  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  @log_freq 1000

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

  def clear() do
    for tab <- [~t[tx], ~t[type], ~t[time], ~t[field], ~t[id_count], ~t[origin], ~t[rev_origin]],
        do: :mnesia.clear_table(tab)
  end

  def min_txi(), do: txi(&first/1)
  def max_txi(), do: txi(&last/1)

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)

  ################################################################################

  defp sync_generation(height, txi) do
    {key_block, micro_blocks} = AE.Db.get_blocks(height)

    {:atomic, next_txi} =
      :mnesia.transaction(fn ->
        kb_txi = (txi == 0 && -1) || txi
        kb_hash = :aec_headers.hash_header(:aec_blocks.to_key_header(key_block)) |> ok!
        kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)
        :mnesia.write(Model.Block, kb_model, :write)

        {{next_txi, _mb_index}, name_cache} =
          micro_blocks |> Enum.reduce({{txi, 0}, %Sync.Name.Cache{}}, &sync_micro_block/2)

        Sync.Name.Cache.persist!(name_cache)
        next_txi
      end)

    next_txi
  end

  defp sync_micro_block(mblock, {{txi, mbi}, name_cache} = st) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_hash = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)) |> ok!
    mb_txi = (txi == 0 && -1) || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    :mnesia.write(Model.Block, mb_model, :write)
    tx_ctx = {{height, mbi}, mb_time}
    mb_txs = :aec_blocks.txs(mblock)

    {next_txi, name_cache} =
      Enum.reduce(mb_txs, {txi, name_cache}, fn signed_tx, {txi, nm_cache} ->
        sync_transaction(signed_tx, txi, tx_ctx, nm_cache)
      end)

    {{next_txi, mbi + 1}, name_cache}
  end

  def sync_transaction(signed_tx, txi, {block_index, mb_time}, name_cache) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    hash = :aetx_sign.hash(signed_tx)
    type = mod.type()
    model_tx = Model.tx(index: txi, id: hash, block_index: block_index, time: mb_time)
    :mnesia.write(Model.Tx, model_tx, :write)
    :mnesia.write(Model.Type, Model.type(index: {type, txi}), :write)
    :mnesia.write(Model.Time, Model.time(index: {mb_time, txi}), :write)
    name_cache = write_links(type, tx, signed_tx, txi, hash, block_index, name_cache)

    for {field, pos} <- AE.tx_ids(type) do
      <<_::256>> = pk = resolve_pubkey(elem(tx, pos), type, field, block_index, name_cache)
      write_field(type, pos, pk, txi)
    end

    {txi + 1, name_cache}
  end

  def write_links(:contract_create_tx, tx, _signed_tx, txi, tx_hash, _bi, name_cache) do
    pk = :aect_contracts.pubkey(:aect_contracts.new(tx))
    write_origin(:contract_create_tx, pk, txi, tx_hash)
    name_cache
  end

  def write_links(:channel_create_tx, _tx, signed_tx, txi, tx_hash, _bi, name_cache) do
    {:ok, pk} = :aesc_utils.channel_pubkey(signed_tx)
    write_origin(:channel_create_tx, pk, txi, tx_hash)
    name_cache
  end

  def write_links(:oracle_register_tx, tx, _signed_tx, txi, tx_hash, _bi, name_cache) do
    pk = :aeo_register_tx.account_pubkey(tx)
    write_origin(:oracle_register_tx, pk, txi, tx_hash)
    name_cache
  end

  def write_links(:name_claim_tx, tx, _signed_tx, txi, tx_hash, bi, name_cache) do
    name = :aens_claim_tx.name(tx)
    {:ok, name_hash} = :aens.get_name_hash(name)
    write_origin(:name_claim_tx, name_hash, txi, tx_hash)
    Sync.Name.Cache.claim(name_cache, name, name_hash, tx, txi, bi)
  end

  def write_links(:name_update_tx, tx, _signed_tx, txi, _tx_hash, bi, name_cache),
    do: Sync.Name.Cache.update(name_cache, :aens_update_tx.name_hash(tx), tx, txi, bi)

  def write_links(:name_revoke_tx, tx, _signed_tx, txi, _tx_hash, bi, name_cache),
    do: Sync.Name.Cache.revoke(name_cache, :aens_revoke_tx.name_hash(tx), tx, txi, bi)

  def write_links(_, _, _, _, _, _, name_cache),
    do: name_cache

  ####

  def write_origin(tx_type, pubkey, txi, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})
    :mnesia.write(Model.Origin, m_origin, :write)
    :mnesia.write(Model.RevOrigin, m_rev_origin, :write)
    write_field(tx_type, nil, pubkey, txi)
  end

  def write_field(tx_type, pos, pubkey, txi) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    :mnesia.write(Model.Field, m_field, :write)
    Model.incr_count({tx_type, pos, pubkey})
  end

  ##########

  def resolve_pubkey(id, :spend_tx, :recipient_id, block_index, name_cache) do
    case :aeser_id.specialize(id) do
      {:name, name_hash} ->
        Sync.Name.Cache.ptr_resolve(name_cache, name_hash, "account_pubkey") ||
          AeMdw.Db.Name.ptr_resolve(block_index, name_hash, "account_pubkey")

      {_tag, pk} ->
        pk
    end
  end

  def resolve_pubkey(id, _, _, _block_index, _name_cache) do
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
      :"$end_of_table" -> nil
      txi -> Model.tx(read_tx!(txi), :block_index) |> elem(0)
    end
  end

  defp log_msg(height, _),
    do: "syncing transactions at generation #{height}"
end
