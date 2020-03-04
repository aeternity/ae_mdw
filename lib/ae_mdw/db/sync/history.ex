defmodule AeMdw.Db.Sync.History do

  @moduledoc "assumes chain index is in place, syncs whole history"

  require AeMdw.Db.Model
  require Ex2ms

  alias AeMdw.Db
  alias AeMdw.Db.{Model, Sync}

  import AeMdw.{Util, Sigil}

  @rev_tx_index_freq 50


  def reset(),
    do: for t <- (Model.tables() -- [~t[meta], ~t[block]]), do: {t, :mnesia.clear_table(t)}

  @log_freq 1000
  def sync() do
    {:atomic, {from_height, from_tx_index}} = :mnesia.transaction(&from_idxs/0)
    to_height = 50000 # TODO
    syncer    = &sync_block/2
    tracker   = Sync.progress_logger(syncer, @log_freq, &log_msg/2)
    rev_cache = %{}

    from_height..to_height
    |> Enum.reduce({from_tx_index, rev_cache}, tracker)

    # from_height..to_height
    # |> Enum.reduce(from_tx_index, &sync_block/2)

  end

  def sync_block(height, {tx_index, rev_cache}) do
    {:ok, kb_header, mb_headers} = fetch_headers(height)
    {:atomic, {{last_tx_index, _mb_index}, last_rev_cache}} =
      :mnesia.transaction(fn ->
        mb_headers
        |> Enum.reduce({{tx_index, 0}, rev_cache}, &sync_micro_block/2)
      end)
    {last_tx_index, last_rev_cache}
  end


  def sync_micro_block(mb_header, {{tx_index, mb_index}, rev_cache}) do
    height = :aec_headers.height(mb_header)
    msecs  = :aec_headers.time_in_msecs(mb_header)
    mhash  = ok!(:aec_headers.hash_header(mb_header))
    block  = :aec_db.get_block(mhash)
    syncer = &sync_transaction(&1, &2, {{height, mb_index}, msecs})

    ~t[block]
    |> write(Model.index(:block, tx_index, %{block_index: {height, mb_index},
                                            block_hash: mhash}))

    {last_tx_index, last_rev_cache} =
      block
      |> :aec_blocks.txs
      |> Enum.reduce({tx_index, rev_cache}, syncer)

    {{last_tx_index, mb_index + 1}, last_rev_cache}
  end


  def sync_transaction(signed_tx, {tx_index, rev_cache}, {block_index, msecs}) do
    {mod, tx} =
      signed_tx
      |> :aetx_sign.tx
      |> :aetx.specialize_callback
    hash = :aetx_sign.hash(signed_tx)
    size = byte_size(:aetx_sign.serialize_to_binary(signed_tx))
    type = mod.type()

    ~t[tx]
    |> write(Model.tx(tx_index, hash, block_index))
    ~t[time]
    |> write(Model.index(:time, tx_index, %{block_index: block_index, time: msecs}))
    ~t[type]
    |> write(Model.index(:type, tx_index, %{type: type}))

    object_tab = ~t[object]
    write_obj  = fn {field, pos} ->
        elem(tx, pos)
        |> List.wrap
        |> Enum.map(fn aeser_id ->
             id  = :aeser_id.specialize(aeser_id)
             obj = Model.index(:object, tx_index, %{type: type, object: {id, field}})
             write(object_tab, obj)
             {{:object, type, id, field}, tx_index}  # returns rev_cache entry
           end)
      end

    next_rev_cache =
      Model.get_meta!({:tx_obj, type})
      |> Stream.map(write_obj)
      |> Stream.flat_map(& &1)
      |> Enum.reduce(Map.put(rev_cache, {:type, type}, tx_index),
           fn {k, v}, cache -> Map.put(cache, k, v) end)

    {tx_index + 1, maybe_flush_rev_cache(next_rev_cache, tx_index)}

  end


  def maybe_flush_rev_cache(rev_cache, tx_index) when rem(tx_index, @rev_tx_index_freq) == 0 do
    rev_type_tab   = ~t[rev_type]
    rev_object_tab = ~t[rev_object]

    for {key, tx_index} <- rev_cache do
      case key do
        {:type, type} ->
          rev_type_tab
          |> write(Model.index(:rev_type, tx_index, %{type: type}))
        {:object, type, id, role} ->
          rev_object_tab
          |> write(Model.index(:rev_object, tx_index, %{type: type, object: {id, role}}))
      end
    end
    %{}
  end
  def maybe_flush_rev_cache(rev_cache, _height),
    do: rev_cache


  def from_idxs() do
    case ~t[tx] |> :mnesia.last() do
      :"$end_of_table" ->
        {0, 0}
      last_tx_index ->
        tx_index      = last_tx_index - rem(last_tx_index, @rev_tx_index_freq)
        {kb_index, _} = Model.tx(read!(~t[tx], tx_index), :block_index)
        {kb_index, tx_index}
    end
  end

  def fetch_headers(height) do
    with {:ok, kb_hash} <- Db.get_block_hash(height),
         {:ok, mb_hdrs} <- fetch_micro_headers(height) do
      {:ok, :aec_db.get_header(kb_hash), mb_hdrs}
    end
  end

  def fetch_micro_headers(height) do
    with {:ok, end_hash} <- Db.get_block_hash(height + 1) do
      mb_headers =
        :aec_db.get_header(end_hash)
        |> :aec_headers.prev_hash
        |> Stream.unfold(&micro_walker/1)
        |> Enum.reverse
      {:ok, mb_headers}
    end
  end

  def micro_walker(hash) do
    with header <- :aec_db.get_header(hash),
         :micro <- :aec_headers.type(header) do
      {header, :aec_headers.prev_hash(header)}
    else
      :key -> nil
    end
  end

  def find_next_tx_index(height) when height >= 0 do
    height..0
    |> Enum.reduce_while(nil,
         &(case test_tx_index(&1) do
             nil -> {:cont, &2}
             {:ok, tx_index} -> {:halt, {:ok, {&1, tx_index + 1}}}
           end))
  end

  def test_tx_index(0), do: {:ok, -1}
  def test_tx_index(h) do
    case :mnesia.dirty_prev(~t[block], {h, -1}) do
      {_, -1} -> nil
      {k, mi} ->
        Db.get_block({k, mi})
        |> map_ok(&{:ok, Model.block(&1, :tx_index)})
    end
  end

  def log_msg(height, _),
    do: "syncing history at block #{height}"

  def write(tab, record),
    do: :mnesia.write(tab, record, :write)

  def read!(tab, key),
    do: :mnesia.read(tab, key) |> one!

  # def put_kv(map, {k, v}),
  #   do: Map.put(map, k, v)

end
