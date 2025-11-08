defmodule AeMdwWeb.GraphQL.Resolvers.Helpers do
  alias AeMdw.Error

  @min_page_limit 1
  @max_page_limit 100
  @default_page_limit 10

  def clamp_page_limit(limit) do
    cond do
      limit == nil -> @default_page_limit
      limit < @min_page_limit -> @min_page_limit
      limit > @max_page_limit -> @max_page_limit
      true -> limit
    end
  end

  # TODO: should nil be returned when only "to_height" is given?
  def make_scope(from_height, to_height) do
    cond do
      from_height && to_height -> {:gen, from_height..to_height}
      from_height && is_nil(to_height) -> {:gen, from_height..from_height}
      true -> nil
    end
  end

  def make_page({:ok, {prev, items, next}}) do
    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: items |> Enum.map(&normalize_map/1)
     }}
  end

  def make_page({:error, err}), do: {:error, format_err(err)}
  def make_page({_prev, _items, _next} = res), do: make_page({:ok, res})

  def make_single({:ok, item}), do: {:ok, normalize_map(item)}
  def make_single({:error, err}), do: {:error, format_err(err)}

  def format_err({reason, val}), do: Error.to_string(reason, val)
  def format_err(_), do: "unrecognized_error"

  def cursor_val(nil), do: nil
  def cursor_val({val, _rev}), do: val

  def maybe_put(map, _k, nil), do: map
  def maybe_put(map, k, v), do: Map.put(map, k, v)

  def maybe_map(nil, _fun), do: nil
  def maybe_map(value, fun), do: fun.(value)

  def normalize_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {normalize_key(k), v}
    end)
    |> Enum.into(%{})
  end

  def normalize_map(value), do: value

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key), do: key
end
