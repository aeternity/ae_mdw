defmodule AeMdw.Db.Sync.Transaction do

  @moduledoc "assumes block index is in place, syncs whole history"

  alias AeMdw.Db.Sync
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.BlockIndex

  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  @rev_tx_index_freq 50
  @log_freq 1000

  ################################################################################

  def sync(max_height \\ :safe, tx_context \\ nil) do
    max_height = Sync.height(is_integer(max_height) && max_height + 1 || max_height)
    bi_max_kbi = BlockIndex.sync(max_height) - 1
    case max_txi() do
      nil when is_nil(tx_context) ->
        sync(0, bi_max_kbi, {0, %{}})
      max_txi when is_integer(max_txi) ->
        {tx_kbi, _} = Model.tx(read_tx!(max_txi), :block_index)
        next_txi    = max_txi + 1
        rev_cache   = case tx_context do
                        nil -> compute_rev_cache(next_txi)
                        {^next_txi, rev_cache} -> rev_cache
                      end
        from_height = tx_kbi + 1
        sync(from_height, bi_max_kbi, {next_txi, rev_cache})
    end
  end

  def sync(from_height, to_height, {txi, rev_cache}) when from_height <= to_height do
    tracker = Sync.progress_logger(&sync_generation/2, @log_freq, &log_msg/2)
    from_height..to_height |> Enum.reduce({txi, rev_cache}, tracker)
  end
  def sync(from_height, to_height, {txi, rev_cache}) when from_height > to_height,
    do: {txi, rev_cache}


  def clear() do
    for tab <- [~t[tx], ~t[type], ~t[rev_type], ~t[object], ~t[rev_object]],
      do: :mnesia.clear_table(tab)
  end


  def rev_tx_index_freq(),
    do: @rev_tx_index_freq

  def min_txi(), do: txi(&first/1)
  def max_txi(), do: txi(&last/1)

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)


  def replay_txis(0),
    do: []
  def replay_txis(next_txi) when next_txi > 0 do
    remains  = rem(next_txi - 1, @rev_tx_index_freq)
    case remains do
      0 -> []
      _ ->
        case {next_txi - remains, next_txi - 1} do
          {0, 0} -> []
          {0, y} -> 1..y
          {i, i} -> [i]
          {x, y} when x > y -> [y]
          {x, y} when x < y -> x..y
        end
    end
  end

  def compute_rev_cache(next_txi) do
    txis = replay_txis(next_txi)
    obj_field_ids =
      fn field, tx, type, txi ->
        List.wrap(tx.tx[field])
        |> Enum.map(&raw_id_cache_key(&1, field, type, txi))
      end
    Enum.reduce(txis, %{},
      fn txi, rev_cache ->
        tx   = Model.to_raw_map(read_tx!(txi))
        type = tx.type
        AeMdw.Node.tx_ids(type)
        |> Stream.map(fn {field, _} -> obj_field_ids.(field, tx, type, txi) end)
        |> Stream.flat_map(& &1)
        |> Enum.reduce(Map.put(rev_cache, {:type, type}, txi),
             fn {k, v}, rev_cache -> Map.put(rev_cache, k, v) end)
      end)
  end


  def keys_range(from_txi),
    do: keys_range(from_txi, last(~t[tx]))
  def keys_range(from_txi, to_txi) when from_txi > to_txi,
    do: %{}
  def keys_range(from_txi, to_txi) when from_txi <= to_txi do
    tx_keys = Enum.to_list(from_txi..to_txi)
    {type_keys, obj_keys} =
      Enum.reduce(tx_keys, {[], []},
        fn txi, {type_keys, obj_keys} ->
          %{type: tx_type, tx: tx} = read_tx!(txi) |> Model.to_raw_map
          objs = for {id_key, _} <- AeMdw.Node.tx_ids(tx_type),
                   do: {tx_type, pk(tx[id_key]), txi}
          {[{tx_type, txi} | type_keys], objs ++ obj_keys}
        end)
    rev_type_keys =
      AeMdw.Node.tx_types()
      |> Stream.map(
           fn tx_type ->
             AeMdw.Db.Stream.Type.rev_index(tx_type)
             |> Stream.take_while(& &1 >= from_txi)
             |> Stream.map(& {tx_type, -&1})
           end)
      |> Stream.concat
      |> Enum.to_list
    rev_obj_tab  = ~t[rev_object]
    rev_obj_keys =
      obj_keys
      |> Stream.map(fn {tx_type, pk, txi} -> {tx_type, pk, -txi} end)
      |> Stream.reject(&(:mnesia.dirty_read(rev_obj_tab, &1) == []))
      |> Enum.to_list
    [{~t[tx], tx_keys},
     {~t[type], type_keys},
     {~t[object], obj_keys},
     {~t[rev_type], rev_type_keys},
     {~t[rev_object], rev_obj_keys}]
    |> Enum.into(%{})
  end

  ################################################################################

  defp sync_generation(height, {txi, rev_cache}) do
    {key_block, micro_blocks} = AeMdw.Node.Db.get_blocks(height)
    {:atomic, {{next_txi, _mb_index}, next_rev_cache}} =
      :mnesia.transaction(fn ->
        kb_txi   = txi == 0 && -1 || txi
        kb_hash  = :aec_headers.hash_header(:aec_blocks.to_key_header(key_block)) |> ok!
        kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)
        :mnesia.write(~t[block], kb_model, :write)
        micro_blocks
        |> Enum.reduce({{txi, 0}, rev_cache}, &sync_micro_block/2)
      end)
    {next_txi, next_rev_cache}
  end

  defp sync_micro_block(mblock, {{txi, mbi}, rev_cache}) do
    height   = :aec_blocks.height(mblock)
    mb_secs  = :aec_blocks.time_in_msecs(mblock)
    mb_hash  = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)) |> ok!
    syncer   = &sync_transaction(&1, &2, {{height, mbi}, mb_secs})
    mb_txi   = txi == 0 && -1 || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    :mnesia.write(~t[block], mb_model, :write)
    {next_txi, next_rev_cache} =
      :aec_blocks.txs(mblock)
      |> Enum.reduce({txi, rev_cache}, syncer)
    {{next_txi, mbi + 1}, next_rev_cache}
  end

  defp sync_transaction(signed_tx, {txi, rev_cache}, {block_index, _mb_secs}) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    hash = :aetx_sign.hash(signed_tx)
    type = mod.type()
    :mnesia.write(~t[tx], Model.tx(index: txi, id: hash, block_index: block_index), :write)
    :mnesia.write(~t[type], Model.type(index: {type, txi}), :write)
    next_rev_cache =
      AeMdw.Node.tx_ids(type)
      |> Stream.map(&write_object(&1, tx, type, txi))
      |> Stream.flat_map(& &1)
      |> Enum.reduce(Map.put(rev_cache, {:type, type}, txi),
           fn {k, v}, cache -> Map.put(cache, k, v) end)
    {txi + 1, maybe_flush_rev_cache(next_rev_cache, txi)}
  end


  defp raw_id_cache_key(aeser_id, field, type, txi) do
    {tag, pubkey} = :aeser_id.specialize(aeser_id)
    {{:object, type, pubkey, tag, field}, txi}
  end

  defp write_object({field, pos}, tx, type, txi) do
    tab = ~t[object]
    List.wrap(elem(tx, pos))
    |> Enum.map(
         fn aeser_id ->
           {{:object, _, pk, tag, _}, _} = key = raw_id_cache_key(aeser_id, field, type, txi)
           model = Model.object(index: {type, pk, txi}, id_tag: tag, role: field)
           :mnesia.write(tab, model, :write)
           key
         end)
  end

  defp maybe_flush_rev_cache(rev_cache, txi) when rem(txi, @rev_tx_index_freq) == 0 do
    rev_type_tab = ~t[rev_type]
    rev_obj_tab  = ~t[rev_object]
    for {key, txi} <- rev_cache do
      case key do
        {:type, type} ->
          rev_type_model = Model.rev_type(index: {type, -txi})
          :mnesia.write(rev_type_tab, rev_type_model, :write)
        {:object, type, pubkey, tag, role} ->
          rev_obj_model  = Model.rev_object(index: {type, pubkey, -txi}, id_tag: tag, role: role)
          :mnesia.write(rev_obj_tab, rev_obj_model, :write)
      end
    end
    %{}
  end
  defp maybe_flush_rev_cache(rev_cache, _txi),
    do: rev_cache


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


  # LATER, stuff below would be used in tests

  # def fmt_h(h),
  #   do: String.pad_leading("#{h}", 6, "0")

  # def tmp_load_rev_cache_dir(path) do
  #   dir_cache = :ets.new(:dir_cache, [:named_table, :public,
  #                                     write_concurrency: true,
  #                                     read_concurrency: true])
  #   entries =
  #     File.ls!(path)
  #     |> Task.async_stream(
  #          fn file ->
  #            ["bin", txi, height | _] = file |> String.split(["/", "_", "."]) |> Enum.reverse
  #            rev_cache = Path.join(path, file) |> File.read! |> :erlang.binary_to_term
  #            [{txi, ""}, {height, ""}] = [txi, height] |> Enum.map(&Integer.parse/1)
  #            {height, {txi, rev_cache}}
  #          end,
  #          ordered: false)
  #     |> Enum.map(&ok!/1)
  #   :ets.insert(dir_cache, entries)
  #   dir_cache
  # end

  # def tmp_load_rev_cache(height) do
  #   pattern = "/tmp/1/#{fmt_h(height)}_*.bin"
  #   fname = Path.wildcard(pattern) |> one!
  #   ["bin", txi, _height | _] = fname |> String.split(["/", "_", "."]) |> Enum.reverse
  #   {txi, ""} = Integer.parse(txi)
  #   {txi, File.read!(fname) |> :erlang.binary_to_term}
  # end


  # def tmp_rc_txis(height) do
  #   pattern = "/tmp/1/#{fmt_h(height)}_*.txt"
  #   fname = Path.wildcard(pattern) |> one!
  #   ["txt", str_txi | _] = fname |> String.split(["/", "_", "."]) |> Enum.reverse
  #   {txi, ""} = Integer.parse(str_txi)
  #   {txi, File.read!(fname) |> Code.string_to_quoted |> ok!}
  # end

  # def tmp_chk_txis(height) do
  #   {next_txi, rc_txis} = tmp_rc_txis(height)
  #   comp_rc_txis = replay_txis(next_txi)
  #   {rc_txis, comp_rc_txis}
  # end

  # def tmp_chk_txis_range(height) when is_integer(height),
  #   do: tmp_chk_txis_range(height..height)
  # def tmp_chk_txis_range(range) do
  #   range
  #   |> Enum.reduce_while(:ok,
  #        fn i, :ok ->
  #          "////////// checking #{i}" |> IO.puts
  #          # {txi, loaded_rc} = tmp_load_rev_cache(i)
  #          {txi, loaded_rc} = one!(:ets.lookup(:dir_cache, i)) |> elem(1)
  #          computed_rc = compute_rev_cache(txi)
  #          case loaded_rc == computed_rc do
  #            true  -> {:cont, :ok}
  #            false -> {:halt, %{height: i,
  #                               txi: txi,
  #                               stored: loaded_rc,
  #                               computed: computed_rc}}
  #          end
  #        end)
  # end

end
