defmodule AeMdw.Util do
  # credo:disable-for-this-file
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.State

  # (U+10FFFD) “􏿽”
  @max_name_bin String.duplicate("􏿽", 100)

  @type opts() :: [{atom(), boolean()}]

  @spec expand?(opts()) :: boolean()
  def expand?(opts), do: Keyword.get(opts, :expand?, false)

  def id(x), do: x

  def ok!({:ok, x}), do: x
  def ok!(err), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def map_ok!({:ok, x}, f), do: f.(x)
  def map_ok!(err, _), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def ok_nil({:ok, x}), do: x
  def ok_nil(_error), do: nil

  def map_some(nil, _f), do: nil
  def map_some(x, f), do: f.(x)

  def inverse(%{} = map),
    do: Enum.reduce(map, %{}, fn {k, v}, map -> put_in(map[v], k) end)

  def compose(f1, f2), do: fn x -> f1.(f2.(x)) end
  def compose(f1, f2, f3), do: fn x -> f1.(f2.(f3.(x))) end

  def chase(nil, _succ), do: []
  def chase(root, succ), do: [root | chase(succ.(root), succ)]

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

  @spec max_int() :: nil
  def max_int(), do: nil

  @spec max_256bit_bin() :: binary()
  def max_256bit_bin(),
    do: <<0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF::256>>

  @spec max_name_bin() :: binary()
  def max_name_bin(), do: @max_name_bin

  @spec min_bin() :: binary()
  def min_bin(), do: <<>>

  # minimum small integer from https://www.erlang.org/doc/efficiency_guide/advanced.html
  @spec min_int() :: integer()
  def min_int(), do: -576_460_752_303_423_488

  @spec min_256bit_int() :: integer()
  def min_256bit_int(), do: -0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

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
    prev_cursor = if cursor + limit <= range_last, do: cursor + limit

    {:ok, prev_cursor, cursor..max(cursor - limit + 1, range_first), next_cursor}
  end

  defp build_gen_pagination(_cursor, _direction, _range, _limit), do: :error

  @spec map_rename(map(), term(), term()) :: map()
  def map_rename(map, current_key, new_key) do
    case Map.fetch(map, current_key) do
      {:ok, value} ->
        map
        |> Map.delete(current_key)
        |> Map.put(new_key, value)

      :error ->
        map
    end
  end

  @spec convert_params(
          map(),
          ({binary(), binary()} -> {:ok, {atom(), term()}} | {:error, term()})
        ) :: {:ok, Keyword.t()} | {:error, term()}
  def convert_params(params, convert_param_fn) do
    Enum.reduce_while(params, {:ok, []}, fn param, {:ok, filters} ->
      case convert_param_fn.(param) do
        {:ok, filter} -> {:cont, {:ok, [filter | filters]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
