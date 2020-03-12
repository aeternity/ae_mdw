defmodule AeMdw.Db.Stream.Util do
  import AeMdw.{Sigil, Util}

  def read(txi),
    do: :mnesia.async_dirty(fn -> :mnesia.read(~t[tx], txi) end)

  def read_one!(txi),
    do: read(txi) |> one!

  def prev(tab, key) do
    fn -> :mnesia.prev(tab, key) end
    |> :mnesia.async_dirty
  end

  def last(tab) do
    fn -> :mnesia.last(tab) end
    |> :mnesia.async_dirty
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
end
