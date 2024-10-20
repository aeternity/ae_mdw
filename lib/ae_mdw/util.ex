defmodule AeMdw.Util do
  @moduledoc """
  Non-domain specific utilities.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.State

  # (U+10FFFD) “􏿽”
  @max_name_bin String.duplicate("􏿽", 100)

  @type opts() :: [{atom(), boolean()}]

  @spec expand?(opts()) :: boolean()
  def expand?(opts), do: Keyword.get(opts, :expand?, false)

  @spec id(term()) :: term()
  def id(x), do: x

  @spec ok!(term()) :: term()
  def ok!({:ok, x}), do: x
  def ok!(err), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  @spec map_some(term(), (term() -> term())) :: term()
  def map_some(nil, _f), do: nil
  def map_some(x, f), do: f.(x)

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
          Enumerable.t(),
          ({binary(), binary()} -> {:ok, {term(), term()}} | {:error, term()})
        ) :: {:ok, map()} | {:error, term()}
  def convert_params(params, convert_param_fn) do
    Enum.reduce_while(params, {:ok, %{}}, fn param, {:ok, filters} ->
      case convert_param_fn.(param) do
        {:ok, {key, val}} -> {:cont, {:ok, Map.put(filters, key, val)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
