defmodule AeMdw.Db.Util do
  alias AeMdw.Db.Model

  require Logger
  require Model

  import AeMdw.{Sigil, Util}

  ################################################################################

  def read(tab, key),
    do: :mnesia.async_dirty(fn -> :mnesia.read(tab, key) end)

  def read!(tab, key),
    do: read(tab, key) |> one!

  def read_tx(txi),
    do: :mnesia.async_dirty(fn -> :mnesia.read(~t[tx], txi) end)

  def read_tx!(txi),
    do: read_tx(txi) |> one!

  def read_block({_, _} = bi),
    do: :mnesia.async_dirty(fn -> :mnesia.read(~t[block], bi) end)

  def read_block(kbi) when is_integer(kbi),
    do: read_block({kbi, -1})

  def read_block!(bi),
    do: read_block(bi) |> one!

  def next_bi!({_kbi, _mbi} = bi),
    do: {_, _} = next(Model.Block, bi)

  def next_bi!(kbi) when is_integer(kbi),
    do: next_bi!({kbi, -1})

  def first_txi(),
    do: ensure_key!(~t[tx], :first)

  def last_txi(),
    do: ensure_key!(~t[tx], :last)

  def first_gen(),
    do: ensure_key!(~t[block], :first) |> (fn {h, -1} -> h end).()

  def last_gen(),
    do: ensure_key!(~t[block], :last) |> (fn {h, -1} -> h end).()

  def first_time(),
    do: ensure_key!(~t[time], :first) |> (fn {t, _txi} -> t end).()

  def last_time(),
    do: ensure_key!(~t[time], :last) |> (fn {t, _txi} -> t end).()

  def range(from, to),
    do: struct(Range, first: from, last: to)

  def prev(tab, key) do
    fn -> :mnesia.prev(tab, key) end
    |> :mnesia.async_dirty()
  end

  def next(tab, key) do
    fn -> :mnesia.next(tab, key) end
    |> :mnesia.async_dirty()
  end

  def first(tab) do
    fn -> :mnesia.first(tab) end
    |> :mnesia.async_dirty()
  end

  def last(tab) do
    fn -> :mnesia.last(tab) end
    |> :mnesia.async_dirty()
  end

  def select(tab, match_spec) do
    fn -> :mnesia.select(tab, match_spec, :read) end
    |> :mnesia.async_dirty()
  end

  def select(tab, match_spec, chunk_size) do
    fn -> :mnesia.select(tab, match_spec, chunk_size, :read) end
    |> :mnesia.async_dirty()
  end

  def select(cont),
    do: :mnesia.async_dirty(fn -> :mnesia.select(cont) end)

  def count(table),
    do: :mnesia.foldl(fn _, c -> c + 1 end, 0, table)

  def ensure_key!(tab, getter) do
    case apply(__MODULE__, getter, [tab]) do
      :"$end_of_table" ->
        raise RuntimeError, message: "can't get #{getter} key for table #{tab}"

      k ->
        k
    end
  end

  def collect_keys(tab, acc, start_key, next_fn, progress_fn) do
    fn -> do_collect_keys(tab, acc, start_key, next_fn, progress_fn) end
    |> :mnesia.async_dirty()
  end

  def do_collect_keys(tab, acc, start_key, next_fn, progress_fn) do
    case next_fn.(tab, start_key) do
      :"$end_of_table" ->
        acc

      next_key ->
        case progress_fn.(next_key, acc) do
          {:halt, res_acc} -> res_acc
          {:cont, next_acc} -> do_collect_keys(tab, next_acc, next_key, next_fn, progress_fn)
        end
    end
  end

  def do_writes(tab_xs),
    do: do_writes(tab_xs, &:mnesia.write(&1, &2, :write))

  def do_writes(tab_xs, db_write) when is_function(db_write, 2),
    do: Enum.each(tab_xs, fn {tab, xs} -> Enum.each(xs, &db_write.(tab, &1)) end)

  def do_dels(tab_keys),
    do: do_dels(tab_keys, &:mnesia.delete(&1, &2, :write))

  def do_dels(tab_keys, db_delete) when is_function(db_delete, 2),
    do: Enum.each(tab_keys, fn {tab, ks} -> Enum.each(ks, &db_delete.(tab, &1)) end)

  def tx_val(tx_rec, field),
    do: tx_val(tx_rec, elem(tx_rec, 0), field)

  def tx_val(tx_rec, tx_type, field),
    do: elem(tx_rec, Enum.find_index(AeMdw.Node.tx_fields(tx_type), &(&1 == field)) + 1)

  def dirty_all(tab),
    do: Enum.map(:mnesia.dirty_all_keys(tab), &one!(:mnesia.dirty_read(tab, &1)))

  def all(tab),
    do: Enum.map(:mnesia.all_keys(tab), &one!(:mnesia.read(tab, &1)))

  def gen_collect(table, init_key_probe, key_tester, progress, new, add, return) do
    return.(
      case progress.(table, init_key_probe) do
        :"$end_of_table" ->
          new.()

        start_key ->
          case key_tester.(start_key) do
            false ->
              new.()

            other ->
              init_acc =
                case other do
                  :skip -> new.()
                  true -> add.(start_key, new.())
                end

              collect_keys(table, init_acc, start_key, progress, fn key, acc ->
                case key_tester.(key) do
                  false -> {:halt, acc}
                  true -> {:cont, add.(key, acc)}
                  :skip -> {:cont, acc}
                end
              end)
          end
      end
    )
  end

  ##########

  def current_height(),
    do: :aec_blocks.height(ok!(:aec_chain.top_key_block()))

  def msecs(msecs) when is_integer(msecs) and msecs > 0, do: msecs
  def msecs(%Date{} = d), do: msecs(date_time(d))
  def msecs(%DateTime{} = d), do: DateTime.to_unix(d) * 1000

  def date_time(%DateTime{} = dt),
    do: dt

  def date_time(msecs) when is_integer(msecs) and msecs > 0,
    do: DateTime.from_unix(div(msecs, 1000)) |> ok!

  def date_time(%Date{} = d) do
    {:ok, dt, 0} = DateTime.from_iso8601(Date.to_iso8601(d) <> " 00:00:00.0Z")
    dt
  end

  def prev_block_type(header) do
    prev_hash = :aec_headers.prev_hash(header)
    prev_key_hash = :aec_headers.prev_key_hash(header)

    cond do
      :aec_headers.height(header) == 0 -> :key
      prev_hash == prev_key_hash -> :key
      true -> :micro
    end
  end

  def proto_vsn(height) do
    hps = AeMdw.Node.height_proto()
    [{vsn, _} | _] = Enum.drop_while(hps, fn {_vsn, min_h} -> height < min_h end)
    vsn
  end

  def block_txi(bi), do: map_one_nil(read_block(bi), &Model.block(&1, :tx_index))

  def block_hash_to_bi(block_hash) do
    case :aec_chain.get_block(block_hash) do
      {:ok, some_block} ->
        {type, header} =
          case some_block do
            {:key_block, header} -> {:key, header}
            {:mic_block, header, _txs, _fraud} -> {:micro, header}
          end

        height = :aec_headers.height(header)

        case height >= last_gen() do
          true ->
            nil

          false ->
            case type do
              :key ->
                {height, -1}

              :micro ->
                collect_keys(Model.Block, nil, {height, <<>>}, &prev/2, fn
                  {^height, _} = bi, nil ->
                    (Model.block(read_block!(bi), :hash) == block_hash &&
                       {:halt, bi}) || {:cont, nil}

                  _k, nil ->
                    {:halt, nil}
                end)
            end
        end

      :error ->
        nil
    end
  end

  def status() do
    {:ok, top_kb} = :aec_chain.top_key_block()
    {node_syncing?, node_progress} = :aec_sync.sync_progress()
    node_height = :aec_blocks.height(top_kb)
    {mdw_tx_index, mdw_height} = safe_mdw_tx_index_and_height()
    mdw_syncing? = is_pid(Process.whereis(AeMdw.Db.Sync.Supervisor))
    {:ok, version} = :application.get_key(:ae_mdw, :vsn)

    %{
      node_version: :aeu_info.get_version(),
      node_revision: :aeu_info.get_revision(),
      node_height: node_height,
      node_syncing: node_syncing?,
      node_progress: node_progress,
      mdw_version: to_string(version),
      mdw_height: mdw_height,
      mdw_tx_index: mdw_tx_index,
      # MDW is always 1 generation behind
      mdw_synced: node_height == mdw_height + 1,
      mdw_syncing: mdw_syncing?
    }
  end

  defp safe_mdw_tx_index_and_height do
    try do
      mdw_tx_index = last_txi()
      {mdw_height, _} = read_tx!(mdw_tx_index) |> Model.tx(:block_index)
      {mdw_tx_index, mdw_height}
    rescue
      _ ->
        {0, 0}
    end
  end
end
