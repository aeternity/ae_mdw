defmodule AeMdw.Util do
  # credo:disable-for-this-file
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.State

  @type opt() :: {:expand?, boolean()} | {:top?, boolean()}
  @type opts() :: [opt()]

  @spec expand?(opts()) :: boolean()
  def expand?(opts), do: Keyword.get(opts, :expand?, false)

  def id(x), do: x

  def one!([x]), do: x
  def one!([]), do: raise(ArgumentError, message: "got empty list")
  def one!(err), do: raise(ArgumentError, message: "got #{inspect(err)}")

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

  def record_to_map(record, [_ | _] = fields) when is_tuple(record) do
    collect = fn {field, idx}, acc -> put_in(acc, [field], elem(record, idx)) end

    fields
    |> Stream.with_index(1)
    |> Enum.reduce(%{}, collect)
  end

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

  @spec merged_stream(any, (any -> any), :backward | :forward) ::
          ({:cont, any} | {:halt, any} | {:suspend, any}, any ->
             {:halted, any} | {:suspended, any, (any -> any)})
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

          _bigger ->
            {{_key, x, rem_stream}, rem_streams} = taker.(streams)

            case pop1.(rem_stream) do
              nil -> {[x], rem_streams}
              next_elt -> {[x], :gb_sets.add(next_elt, rem_streams)}
            end
        end
      end,
      fn _any -> :ok end
    )
  end

  @spec max_256bit_int() :: integer()
  def max_256bit_int(),
    do: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

  @spec max_256bit_bin() :: binary()
  def max_256bit_bin(), do: <<max_256bit_int()::256>>

  @spec max_name_bin() :: binary
  def max_name_bin(), do: String.duplicate("z", 128)

  @spec min_int() :: integer()
  def min_int(), do: -100

  @spec min_bin() :: binary()
  def min_bin(), do: <<>>

  @spec contains_unicode?(binary()) :: boolean()
  def contains_unicode?(string) do
    string
    |> String.codepoints()
    |> Enum.reduce_while(
      false,
      fn cp, false ->
        case String.next_grapheme_size(cp) do
          {1, ""} -> {:cont, false}
          {_, ""} -> {:halt, true}
        end
      end
    )
  end

  @spec parse_int(binary()) :: {:ok, integer()} | :error
  def parse_int(int_bin) do
    case Integer.parse(int_bin) do
      {int, ""} -> {:ok, int}
      _invalid_int -> :error
    end
  end

  @doc """
  Given a cursor (which can be `nil`) and a range (first/last gen) computes the
  range of generations to be fetched, together with the previous/next generation.
  """
  @spec build_gen_pagination(
          Blocks.height() | nil,
          State.direction(),
          {Blocks.height(), Blocks.height()},
          Collection.limit(),
          Blocks.height()
        ) ::
          {:ok, Blocks.height() | nil, Range.t(), Blocks.height() | nil} | :error

  def build_gen_pagination(cursor, direction, {range_first, range_last}, limit, last_gen) do
    build_gen_pagination(
      cursor,
      direction,
      {max(range_first, 0), min(range_last, last_gen)},
      limit
    )
  end

  defp build_gen_pagination(nil, :forward, {range_first, range_last}, limit),
    do: build_gen_pagination(range_first, :forward, {range_first, range_last}, limit)

  defp build_gen_pagination(cursor, :forward, {range_first, range_last}, limit)
       when range_first <= cursor and cursor <= range_last do
    next_cursor = if cursor + limit <= range_last, do: cursor + limit
    prev_cursor = if cursor - limit >= range_first, do: cursor - limit

    {:ok, prev_cursor, cursor..min(cursor + limit - 1, range_last), next_cursor}
  end

  defp build_gen_pagination(nil, :backward, {range_first, range_last}, limit),
    do: build_gen_pagination(range_last, :backward, {range_first, range_last}, limit)

  defp build_gen_pagination(cursor, :backward, {range_first, range_last}, limit)
       when range_first <= cursor and cursor <= range_last do
    next_cursor = if cursor - limit >= range_first, do: cursor - limit
    prev_cursor = if cursor + limit >= range_last, do: cursor + limit

    {:ok, prev_cursor, cursor..max(cursor - limit + 1, range_first), next_cursor}
  end

  defp build_gen_pagination(_cursor, _direction, _range, _limit), do: :error
end
