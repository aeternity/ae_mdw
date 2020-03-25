defmodule AeMdw.Db.Util do
  require Logger

  import AeMdw.{Sigil, Util}

  ################################################################################

  def read_tx(txi),
    do: :mnesia.async_dirty(fn -> :mnesia.read(~t[tx], txi) end)

  def read_tx!(txi),
    do: read_tx(txi) |> one!

  def read_block({_, _} = bi),
    do: :mnesia.async_dirty(fn -> :mnesia.read(~t[block], bi) end)

  def read_block!({_, _} = bi),
    do: read_block(bi) |> one!

  def prev(tab, key) do
    fn -> :mnesia.prev(tab, key) end
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

  def delete_records(tab_keys) do
    fn ->
      for {tab, ks} <- tab_keys,
          do: ks |> Enum.each(&:mnesia.delete(tab, &1, :write))

      :ok
    end
    |> :mnesia.transaction()
  end
end
