defmodule AeMdw.Db.Stream.Object do
  require Ex2ms

  alias AeMdw.Validate

  import AeMdw.{Sigil, Util, Db.Util}

  ################################################################################

  def index(pubkey),
    do: index(pubkey, AeMdw.Node.tx_types())

  def index(pubkey, tx_types) do
    pubkey = Validate.id!(pubkey)
    tx_types = validate_types!(tx_types)
    Stream.resource(
      fn ->
        tab = ~t[object]

        tx_types
        |> List.wrap()
        |> Task.async_stream(&select(tab, match_spec(&1, pubkey), 5), ordered: false)
        |> Enum.reduce(
          :gb_sets.new(),
          fn
            {:ok, {[], _cont}}, acc -> acc
            {:ok, {txis, cont}}, acc -> :gb_sets.add({txis, cont}, acc)
          end
        )
      end,
      &stream_next/1,
      &id/1
    )
  end

  def tx(pubkey),
    do: tx(pubkey, AeMdw.Node.tx_types())

  def tx(pubkey, tx_types) do
    pubkey
    |> index(tx_types)
    |> Stream.map(&read_tx!/1)
  end

  def rev_index(pubkey),
    do: rev_index(pubkey, AeMdw.Node.tx_types())

  def rev_index(pubkey, tx_types) do
    pubkey = Validate.id!(pubkey)
    tx_types = validate_types!(tx_types)
    Stream.resource(
      fn ->
        tx_types
        |> List.wrap()
        |> Task.async_stream(&rev_init(pubkey, &1), ordered: false)
        |> Enum.reduce(
          :gb_sets.new(),
          fn
            {:ok, nil}, acc ->
              acc

            {:ok, {_, {_, top_mark, _}, tx_type} = desc}, acc ->
              :gb_sets.add(
                case rev_maybe_pull(pubkey, desc) do
                  nil -> {[-top_mark], {[], nil, nil}, tx_type}
                  desc -> desc
                end,
                acc
              )
          end
        )
      end,
      &rev_stream_next(pubkey, &1),
      &id/1
    )
  end

  def rev_tx(pubkey),
    do: rev_tx(pubkey, AeMdw.Node.tx_types())

  def rev_tx(pubkey, tx_types) do
    pubkey
    |> rev_index(tx_types)
    |> Stream.map(&read_tx!/1)
  end

  ################################################################################

  def validate_types!(tx_types),
    do: Enum.map(List.wrap(tx_types), &Validate.tx_type!/1)


  defp match_spec(tx_type, object_pubkey) do
    Ex2ms.fun do
      {:object, {^tx_type, ^object_pubkey, txi}, _, _} -> txi
    end
  end

  defp stream_next({0, nil}), do: {:halt, :done}

  defp stream_next(elts) do
    case :gb_sets.take_smallest(elts) do
      {{[], cont}, elts} ->
        stream_next(
          case select(cont) do
            {[_ | _] = txis, cont} -> :gb_sets.add({txis, cont}, elts)
            _ -> elts
          end
        )

      {{[txi | txis], cont}, elts} ->
        {[txi], :gb_sets.add({txis, cont}, elts)}
    end
  end

  defp rev_match_spec(tx_type, object_pubkey) do
    Ex2ms.fun do
      {:rev_object, {^tx_type, ^object_pubkey, txi}, _, _} -> -txi
    end
  end

  defp rev_init(pubkey, tx_type) do
    case select(~t[rev_object], rev_match_spec(tx_type, pubkey), 1) do
      {[], _cont} ->
        nil

      {[top_mark | marks], cont} ->
        from_key = {tx_type, pubkey, top_mark}
        progress = unbounded_progress(tx_type, pubkey)
        txis = collect_keys(~t[object], [], from_key, &:mnesia.next/2, progress)
        {txis, {marks, top_mark, cont}, tx_type}
    end
  end

  defp rev_stream_next(_, {0, nil}), do: {:halt, :done}

  defp rev_stream_next(pubkey, elts) do
    case :gb_sets.take_smallest(elts) do
      {{[], {marks, top_mark, cont}, tx_type}, elts} ->
        rev_stream_next(
          pubkey,
          case rev_maybe_pull(pubkey, {[], {marks, top_mark, cont}, tx_type}) do
            nil -> elts
            desc -> :gb_sets.add(desc, elts)
          end
        )

      {{[txi | txis], {marks, top_mark, cont}, tx_type}, elts} ->
        {[-txi], :gb_sets.add({txis, {marks, top_mark, cont}, tx_type}, elts)}
    end
  end

  defp rev_maybe_pull(_pubkey, {[], {[], _top_mark, nil}, _tx_type}),
    do: nil

  defp rev_maybe_pull(_pubkey, {[_ | _] = txis, {marks, top_mark, cont}, tx_type}),
    do: {txis, {marks, top_mark, cont}, tx_type}

  defp rev_maybe_pull(pubkey, {[], {[min_mark | marks], top_mark, cont}, tx_type}) do
    progress = bounded_progress(tx_type, pubkey, top_mark, :forward)
    from_key = {tx_type, pubkey, min_mark}
    [_ | _] = txis = collect_keys(~t[object], [], from_key, &:mnesia.next/2, progress)
    {txis, {marks, min_mark, cont}, tx_type}
  end

  defp rev_maybe_pull(pubkey, {[], {[], top_mark, cont}, tx_type}) do
    case select(cont) do
      {[_ | _] = marks, cont} ->
        rev_maybe_pull(pubkey, {[], {marks, top_mark, cont}, tx_type})

      _ ->
        min_mark = top_mark - AeMdw.Db.Sync.Transaction.rev_tx_index_freq()
        from_key = {tx_type, pubkey, top_mark}
        progress = bounded_progress(tx_type, pubkey, min_mark, :backward)
        txis = collect_keys(~t[object], [-top_mark], from_key, &:mnesia.prev/2, progress)
        {Enum.reverse(txis), {[], top_mark, nil}, tx_type}
    end
  end

  defp unbounded_progress(tx_type, pubkey) do
    fn
      {^tx_type, ^pubkey, i}, acc -> {:cont, [-i | acc]}
      _, acc -> {:halt, acc}
    end
  end

  defp bounded_progress(tx_type, pubkey, mark, :forward) do
    fn
      {^tx_type, ^pubkey, i}, acc when i <= mark -> {:cont, [-i | acc]}
      _, acc -> {:halt, acc}
    end
  end

  defp bounded_progress(tx_type, pubkey, mark, :backward) do
    fn
      {^tx_type, ^pubkey, i}, acc when i >= mark -> {:cont, [-i | acc]}
      _, acc -> {:halt, acc}
    end
  end
end
