defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "assumes block index is in place, syncs whole history"

  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.BlockIndex
  alias AeMdw.Db.Stream, as: DBS

  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  @log_freq 1000

  ################################################################################

  def sync(max_height \\ :safe) do
    max_height = Sync.height((is_integer(max_height) && max_height + 1) || max_height)
    bi_max_kbi = BlockIndex.sync(max_height) - 1

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
    for tab <- [~t[tx], ~t[type], ~t[time], ~t[object], ~t[object], ~t[rev_object]],
        do: :mnesia.clear_table(tab)
  end

  def min_txi(), do: txi(&first/1)
  def max_txi(), do: txi(&last/1)

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)

  ################################################################################

  defp sync_generation(height, txi) do
    {key_block, micro_blocks} = AE.Db.get_blocks(height)

    {:atomic, {next_txi, _mb_index}} =
      :mnesia.transaction(fn ->
        kb_txi = (txi == 0 && -1) || txi
        kb_hash = :aec_headers.hash_header(:aec_blocks.to_key_header(key_block)) |> ok!
        kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)
        :mnesia.write(Model.Block, kb_model, :write)
        micro_blocks |> Enum.reduce({txi, 0}, &sync_micro_block/2)
      end)

    next_txi
  end

  defp sync_micro_block(mblock, {txi, mbi}) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_hash = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)) |> ok!
    syncer = &sync_transaction(&1, &2, {{height, mbi}, mb_time})
    mb_txi = (txi == 0 && -1) || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    :mnesia.write(Model.Block, mb_model, :write)
    next_txi = :aec_blocks.txs(mblock) |> Enum.reduce(txi, syncer)
    {next_txi, mbi + 1}
  end

  defp sync_transaction(signed_tx, txi, {block_index, mb_time}) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    hash = :aetx_sign.hash(signed_tx)
    type = mod.type()

    :mnesia.write(
      Model.Tx,
      Model.tx(index: txi, id: hash, block_index: block_index, time: mb_time),
      :write
    )

    :mnesia.write(Model.Type, Model.type(index: {type, txi}), :write)
    :mnesia.write(Model.Time, Model.time(index: {mb_time, txi}), :write)
    write_links(type, tx, signed_tx, txi, hash)
    AE.tx_ids(type) |> Enum.each(&write_object(&1, tx, type, txi))
    txi + 1
  end

  defp raw_id_cache_key(aeser_id, field, type, txi) do
    {tag, pubkey} = :aeser_id.specialize(aeser_id)
    {{:object, type, pubkey, tag, field}, txi}
  end

  defp write_object({field, pos}, tx, type, txi) do
    List.wrap(elem(tx, pos))
    |> Enum.map(fn aeser_id ->
      {{:object, _, pk, tag, _}, _} = key = raw_id_cache_key(aeser_id, field, type, txi)
      model = Model.object(index: {type, pk, txi}, id_tag: tag, role: field)
      :mnesia.write(Model.Object, model, :write)
      key
    end)
  end

  def write_links(:contract_create_tx, tx, _signed_tx, txi, tx_hash) do
    pk = :aect_contracts.pubkey(:aect_contracts.new(tx))
    model_obj = Model.object(index: {:contract_create_tx, pk, txi})
    :mnesia.write(Model.Object, model_obj, :write)
    write_origin({:contract, pk, txi}, tx_hash)
  end

  def write_links(:channel_create_tx, _tx, signed_tx, txi, tx_hash) do
    {:ok, pk} = :aesc_utils.channel_pubkey(signed_tx)
    model_obj = Model.object(index: {:channel_create_tx, pk, txi})
    :mnesia.write(Model.Object, model_obj, :write)
    write_origin({:channel, pk, txi}, tx_hash)
  end

  def write_links(:oracle_register_tx, tx, _signed_tx, txi, tx_hash) do
    pk = :aeser_id.create(:oracle, :aeo_register_tx.account_pubkey(tx))
    model_obj = Model.object(index: {:oracle_register_tx, pk, txi})
    :mnesia.write(Model.Object, model_obj, :write)
    write_origin({:oracle, pk, txi}, tx_hash)
  end

  def write_links(:name_claim_tx, tx, _signed_tx, txi, tx_hash) do
    name = :aens_claim_tx.name(tx)
    {:ok, name_hash} = :aens.get_name_hash(name)
    model_obj = Model.object(index: {:name_claim_tx, name_hash, txi})
    :mnesia.write(Model.Object, model_obj, :write)
    write_origin({:name, name_hash, txi}, tx_hash)
  end

  def write_links(_, _, _, _, _),
    do: :ok

  defp write_origin({pk_type, pubkey, txi}, tx_hash) do
    origin = Model.origin(index: {pk_type, pubkey, txi}, tx_id: tx_hash)
    rev_origin = Model.rev_origin(index: {txi, pk_type, pubkey})
    :mnesia.write(Model.Origin, origin, :write)
    :mnesia.write(Model.RevOrigin, rev_origin, :write)
  end

  ##########

  defp pk({:id, _, _} = id) do
    {_, pk} = :aeser_id.specialize(id)
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

  ################################################################################
  # Invalidations - keys for records to delete in case of fork

  def keys_range(from_txi),
    do: keys_range(from_txi, last(Model.Tx))

  def keys_range(from_txi, to_txi) when from_txi > to_txi,
    do: %{}

  def keys_range(from_txi, to_txi) when from_txi <= to_txi do
    tx_keys = Enum.to_list(from_txi..to_txi)

    {type_keys, obj_keys} =
      Enum.reduce(tx_keys, {[], []}, fn txi, {type_keys, obj_keys} ->
        %{tx: %{type: tx_type} = tx} = read_tx!(txi) |> Model.tx_to_raw_map()

        objs =
          for {id_key, _} <- AE.tx_ids(tx_type),
              do: {tx_type, pk(tx[id_key]), txi}

        {[{tx_type, txi} | type_keys], objs ++ obj_keys}
      end)

    time_keys = time_keys_range(from_txi, to_txi)
    {origin_keys, rev_origin_keys} = origin_keys_range(from_txi, to_txi)

    %{
      Model.Tx => tx_keys,
      Model.Type => type_keys,
      Model.Time => time_keys,
      Model.Object => obj_keys,
      Model.Origin => origin_keys,
      Model.RevOrigin => rev_origin_keys
    }
  end

  def time_keys_range(from_txi, to_txi) do
    bi_time = fn bi ->
      Model.block(read!(Model.Block, bi), :hash)
      |> :aec_db.get_header()
      |> :aec_headers.time_in_msecs()
    end

    from_bi = Model.tx(read_tx!(from_txi), :block_index)

    folder = fn tx, {bi, time, acc} ->
      case Model.tx(tx, :block_index) do
        ^bi ->
          {bi, time, [{time, Model.tx(tx, :index)} | acc]}

        new_bi ->
          new_time = bi_time.(new_bi)
          {new_bi, new_time, [{new_time, Model.tx(tx, :index)} | acc]}
      end
    end

    {_, _, keys} =
      from_txi..to_txi
      |> DBS.map(Model.Tx)
      |> Enum.reduce({from_bi, bi_time.(from_bi), []}, folder)

    keys
  end

  def origin_keys_range(from_txi, to_txi) do
    case :mnesia.dirty_next(Model.RevOrigin, {from_txi, :_, nil}) do
      :"$end_of_table" ->
        {[], []}

      start_key ->
        push_key = fn {txi, pk_type, pk}, {origins, rev_origins} ->
          {[{pk_type, pk, txi} | origins], [{txi, pk_type, pk} | rev_origins]}
        end

        collect_keys(Model.RevOrigin, push_key.(start_key, {[], []}), start_key, &next/2, fn
          {txi, pk_type, pk}, acc when txi <= to_txi ->
            {:cont, push_key.({txi, pk_type, pk}, acc)}

          {txi, _, _}, acc when txi > to_txi ->
            {:halt, acc}
        end)
    end
  end
end
