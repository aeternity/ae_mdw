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
    from_height..to_height |> Enum.reduce(txi, tracker)
  end

  def sync(from_height, to_height, txi) when from_height > to_height,
    do: txi

  def clear() do
    for tab <- [~t[tx], ~t[type], ~t[object]],
        do: :mnesia.clear_table(tab)
  end

  def min_txi(), do: txi(&first/1)
  def max_txi(), do: txi(&last/1)

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)


  def keys_range(from_txi),
    do: keys_range(from_txi, last(~t[tx]))

  def keys_range(from_txi, to_txi) when from_txi > to_txi,
    do: %{}

  def keys_range(from_txi, to_txi) when from_txi <= to_txi do
    tx_keys = Enum.to_list(from_txi..to_txi)

    {type_keys, obj_keys} =
      Enum.reduce(tx_keys, {[], []}, fn txi, {type_keys, obj_keys} ->
        %{type: tx_type, tx: tx} = read_tx!(txi) |> Model.tx_to_raw_map()

        objs =
          for {id_key, _} <- AE.tx_ids(tx_type),
              do: {tx_type, pk(tx[id_key]), txi}

        {[{tx_type, txi} | type_keys], objs ++ obj_keys}
      end)

    time_keys = time_keys_range(from_txi, to_txi)

    %{~t[tx] => tx_keys,
      ~t[type] => type_keys,
      ~t[time] => time_keys,
      ~t[object] => obj_keys}
  end


  def time_keys_range(from_txi, to_txi) do
    bi_time = fn bi ->
      Model.block(read!(~t[block], bi), :hash)
      |> :aec_db.get_header
      |> :aec_headers.time_in_msecs
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
      |> DBS.map(~t[tx])
      |> Enum.reduce({from_bi, bi_time.(from_bi), []}, folder)
    keys
  end


  ################################################################################

  defp sync_generation(height, txi) do
    {key_block, micro_blocks} = AE.Db.get_blocks(height)

    {:atomic, {next_txi, _mb_index}} =
      :mnesia.transaction(fn ->
        kb_txi = (txi == 0 && -1) || txi
        kb_hash = :aec_headers.hash_header(:aec_blocks.to_key_header(key_block)) |> ok!
        kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)
        :mnesia.write(~t[block], kb_model, :write)
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
    :mnesia.write(~t[block], mb_model, :write)
    next_txi = :aec_blocks.txs(mblock) |> Enum.reduce(txi, syncer)
    {next_txi, mbi + 1}
  end

  defp sync_transaction(signed_tx, txi, {block_index, mb_time}) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    hash = :aetx_sign.hash(signed_tx)
    type = mod.type()
    :mnesia.write(~t[tx], Model.tx(index: txi, id: hash, block_index: block_index, time: mb_time), :write)
    :mnesia.write(~t[type], Model.type(index: {type, txi}), :write)
    :mnesia.write(~t[time], Model.time(index: {mb_time, txi}), :write)
    AE.tx_ids(type) |> Enum.each(&write_object(&1, tx, type, txi))
    txi + 1
  end

  defp raw_id_cache_key(aeser_id, field, type, txi) do
    {tag, pubkey} = :aeser_id.specialize(aeser_id)
    {{:object, type, pubkey, tag, field}, txi}
  end

  defp write_object({field, pos}, tx, type, txi) do
    tab = ~t[object]

    List.wrap(elem(tx, pos))
    |> Enum.map(fn aeser_id ->
      {{:object, _, pk, tag, _}, _} = key = raw_id_cache_key(aeser_id, field, type, txi)
      model = Model.object(index: {type, pk, txi}, id_tag: tag, role: field)
      :mnesia.write(tab, model, :write)
      key
    end)
  end


  defp pk({:id, _, _} = id) do
    {_, pk} = :aeser_id.specialize(id)
    pk
  end

  defp txi(f) do
    case f.(~t[tx]) do
      :"$end_of_table" -> nil
      txi -> txi
    end
  end

  defp kbi(f) do
    case f.(~t[tx]) do
      :"$end_of_table" -> nil
      txi -> Model.tx(read_tx!(txi), :block_index) |> elem(0)
    end
  end

  defp log_msg(height, _),
    do: "syncing transactions at generation #{height}"

end
