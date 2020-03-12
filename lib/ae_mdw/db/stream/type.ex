defmodule AeMdw.Db.Stream.Type do

  require Ex2ms

  import AeMdw.{Sigil, Util, Db.Stream.Util}

  @mnesia_chunk_size 20


  def index(tx_type) do
    Stream.resource(
      fn ->
        mspec = Ex2ms.fun do {:type, {^tx_type, i}, _} -> i end
        select(~t[type], mspec, @mnesia_chunk_size)
      end,
      &stream_next/1,
      &id/1
    )
  end

  def tx(tx_type) do
    tx_type
    |> index
    |> Stream.map(&read_one!/1)
  end


  def rev_index(tx_type) do
    Stream.resource(
      fn ->
        mspec = Ex2ms.fun do {:rev_type, {^tx_type, i}, _} -> -i end
        {tx_type, [], nil, select(~t[rev_type], mspec, 1)}
      end,
      &rev_stream_next/1,
      &id/1
    )
  end

  def rev_tx(tx_type) do
    tx_type
    |> rev_index
    |> Stream.map(&read_one!/1)
  end

  ################################################################################

  defp stream_next(:"$end_of_table"), do: {:halt, :done}
  defp stream_next({[txi | txis], cont}), do: {[txi], {txis, cont}}
  defp stream_next({[], cont}) do
    case select(cont) do
      {[txi | txis], cont} -> {[txi], {txis, cont}}
      _ -> {:halt, :done}
    end
  end


  defp rev_stream_next({_tx_type, [], nil, {[], _}}),
    do: {:halt, :done}
  defp rev_stream_next({tx_type, [txi | txis], top_mark, {marks, cont}}),
    do: {[txi], {tx_type, txis, top_mark, {marks, cont}}}
  defp rev_stream_next({tx_type, [], top_mark, {[], cont}}) do
    case select(cont) do
      {[_|_] = marks, cont} ->
        rev_stream_next({tx_type, [], top_mark, {marks, cont}})
      _ ->
        min_mark = top_mark - AeMdw.Db.Sync.History.rev_tx_index_freq()
        progress = bounded_progress(tx_type, min_mark, :backward)
        txis = collect_keys(~t[type], [top_mark], {tx_type, top_mark}, &:mnesia.prev/2, progress)
        rev_stream_next({tx_type, Enum.reverse(txis), nil, {[], nil}})
    end
  end
  defp rev_stream_next({tx_type, [], top_mark, {[mark | marks], cont}}) do
    txis = collect_keys(~t[type], [], {tx_type, mark}, &:mnesia.next/2,
             case is_nil(top_mark) do
               true  -> unbounded_progress(tx_type)
               false -> bounded_progress(tx_type, top_mark, :forward)
             end)
    rev_stream_next({tx_type, txis, mark, {marks, cont}})
  end


  defp unbounded_progress(tx_type) do
    fn {^tx_type, i}, acc -> {:cont, [i | acc]}
       _, acc -> {:halt, acc}
    end
  end
  defp bounded_progress(tx_type, mark, :forward) do
    fn {^tx_type, i}, acc when i <= mark -> {:cont, [i | acc]}
       _, acc -> {:halt, acc}
    end
  end
  defp bounded_progress(tx_type, mark, :backward) do
    fn {^tx_type, i}, acc when i >= mark -> {:cont, [i | acc]}
       _, acc -> {:halt, acc}
    end
  end


end
