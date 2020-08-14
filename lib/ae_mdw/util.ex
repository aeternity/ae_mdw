defmodule AeMdw.Util do
  def id(x), do: x

  def one!([x]), do: x
  def one!([]), do: raise(ArgumentError, message: "got empty list")
  def one!(err), do: raise(ArgumentError, message: "got #{inspect(err)}")

  def one([x]), do: x
  def one([]), do: nil

  def map_one([x], f), do: f.(x)
  def map_one([], _), do: {:error, :not_found}
  def map_one(_, _), do: {:error, :too_many}

  def map_one!([x], f), do: f.(x)
  def map_one!([], _), do: raise(ArgumentError, message: "got empty list")
  def map_one!(err, _), do: raise(ArgumentError, message: "got #{inspect(err)}")

  def map_one_nil([x], f), do: f.(x)
  def map_one_nil(_other, _), do: nil

  def ok!({:ok, x}), do: x
  def ok!(err), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def map_ok({:ok, x}, f), do: f.(x)
  def map_ok(error, _), do: error

  def map_ok!({:ok, x}, f), do: f.(x)
  def map_ok!(err, _), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def ok_nil({:ok, x}), do: x
  def ok_nil(_error), do: nil

  def unwrap_nil({_, val}), do: val
  def unwrap_nil(_), do: nil

  def map_ok_nil({:ok, x}, f), do: f.(x)
  def map_ok_nil(_error, _), do: nil

  def map_some(nil, _f), do: nil
  def map_some(x, f), do: f.(x)

  def map_tuple2({a, b}, f), do: {f.(a), f.(b)}

  def flip_tuple({a, b}), do: {b, a}

  def sort_tuple2({a, b} = t) when a <= b, do: t
  def sort_tuple2({a, b}) when a > b, do: {b, a}

  def inverse(%{} = map),
    do: Enum.reduce(map, %{}, fn {k, v}, map -> put_in(map[v], k) end)

  def compose(f1, f2), do: fn x -> f1.(f2.(x)) end
  def compose(f1, f2, f3), do: fn x -> f1.(f2.(f3.(x))) end

  def prx(x),
    do: x |> IO.inspect(pretty: true, limit: :infinity)

  def prx(x, label),
    do: x |> IO.inspect(label: label, pretty: true, limit: :infinity)

  def is_mapset(%{__struct__: MapSet}), do: true
  def is_mapset(_), do: false

  def to_list_like(nil), do: [nil]
  def to_list_like(xs), do: ((is_mapset(xs) or is_list(xs)) && xs) || List.wrap(xs)

  def chase(nil, _succ), do: []
  def chase(root, succ), do: [root | chase(succ.(root), succ)]

  def kvs_to_map(params) when is_list(params) do
    for {k, kvs} <- Enum.group_by(params, &elem(&1, 0)), reduce: %{} do
      acc ->
        case kvs do
          [_, _ | _] ->
            raise ArgumentError, message: "duplicate key #{inspect(k)} in #{inspect(params)}"

          [{_, val}] ->
            put_in(acc[k], val)
        end
    end
  end

  def tuple_to_map({k, v}),
    do: %{k => v}

  def apply_tuple(mod, fun, tup_args) when is_tuple(tup_args),
    do: apply(mod, fun, :erlang.tuple_to_list(tup_args))

  def gets(x, mod, fkws),
    do: fkws |> Enum.map(&apply(mod, &1, [x]))

  def record_to_map(record, [_ | _] = fields) when is_tuple(record) do
    collect = fn {field, idx}, acc -> put_in(acc, [field], elem(record, idx)) end

    fields
    |> Stream.with_index(1)
    |> Enum.reduce(%{}, collect)
  end

  def product(xs, ys),
    do: for(x <- xs, y <- ys, do: {x, y})

  def combinations(list, num)
  def combinations(_list, 0), do: [[]]
  def combinations(list = [], _num), do: list

  def combinations([head | tail], num),
    do: Enum.map(combinations(tail, num - 1), &[head | &1]) ++ combinations(tail, num)

  def permutations([]), do: [[]]

  def permutations(list),
    do: for(elem <- list, rest <- permutations(list -- [elem]), do: [elem | rest])

  def merge_maps([%{} = m0 | rem_maps]),
    do: Enum.reduce(rem_maps, m0, &Map.merge(&2, &1))

  def merge_maps([%{} = m0 | rem_maps], merger),
    do: Enum.reduce(rem_maps, m0, &Map.merge(&2, &1, merger))

  def flatten_map_values(map) do
    map
    |> Enum.map(fn {k, vs} -> {k, :lists.flatten(vs)} end)
    |> Enum.into(%{})
  end

  defp reduce_skip_while_pull(stream, acc, fun) do
    case StreamSplit.take_and_drop(stream, 1) do
      {[], _} ->
        :halt

      {[x], stream} ->
        case fun.(x, acc) do
          :halt -> :halt
          {:cont, acc, x} -> {:cont, stream, acc, x}
          {:next, acc} -> reduce_skip_while_pull(stream, acc, fun)
        end
    end
  end

  def reduce_skip_while(stream, acc, fun) do
    Stream.resource(
      fn -> {stream, acc} end,
      fn {stream, acc} ->
        case reduce_skip_while_pull(stream, acc, fun) do
          :halt -> {:halt, :done}
          {:cont, stream, acc, x} -> {[x], {stream, acc}}
        end
      end,
      fn _ -> :ok end
    )
  end

  def gb_tree_stream(tree, dir)
      when dir in [:forward, :backward] do
    taker =
      case dir do
        :forward -> &:gb_trees.take_smallest/1
        :backward -> &:gb_trees.take_largest/1
      end

    Stream.resource(
      fn -> tree end,
      fn tree ->
        case :gb_trees.size(tree) do
          0 ->
            {:halt, nil}

          _ ->
            {k, v, tree} = taker.(tree)
            {[{k, v}], tree}
        end
      end,
      fn _ -> :ok end
    )
  end

  def ets_stream_pull({tab, :"$end_of_table", _}),
    do: {:halt, tab}

  def ets_stream_pull({tab, key, advance}) do
    case :ets.lookup(tab, key) do
      [tuple] ->
        {[tuple], {tab, advance.(tab, key), advance}}

      [] ->
        ets_stream_pull({tab, advance.(tab, key), advance})
    end
  end

  def ets_stream(tab, dir) do
    {advance, init_key} =
      case dir do
        :forward -> {&:ets.next/2, &:ets.first/1}
        :backward -> {&:ets.prev/2, &:ets.last/1}
      end

    Stream.resource(
      fn -> {tab, init_key.(tab), advance} end,
      &ets_stream_pull/1,
      fn _ -> :ok end
    )
  end

  def merged_stream(streams, key, dir) when is_function(key, 1) do
    taker =
      case dir do
        :forward -> &:gb_sets.take_smallest/1
        :backward -> &:gb_sets.take_largest/1
      end

    pop1 = fn stream ->
      case StreamSplit.take_and_drop(stream, 1) do
        {[x], rem_stream} ->
          {key.(x), x, rem_stream}

        {[], _} ->
          nil
      end
    end

    Stream.resource(
      fn ->
        streams
        |> Stream.map(pop1)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()
        |> :gb_sets.from_list()
      end,
      fn streams ->
        case :gb_sets.size(streams) do
          0 ->
            {:halt, nil}

          _ ->
            {{_, x, rem_stream}, rem_streams} = taker.(streams)
            next_elt = pop1.(rem_stream)
            {[x], (next_elt && :gb_sets.add(next_elt, rem_streams)) || rem_streams}
        end
      end,
      fn _ -> :ok end
    )
  end
end
