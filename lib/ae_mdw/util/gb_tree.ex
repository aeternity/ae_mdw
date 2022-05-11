defmodule AeMdw.Util.GbTree do
  @moduledoc """
  Functional key-value binary-tree implementation.

  This is similar to the Erlang implementation of :gb_tree, but it also deals
  with backwards key and iterators.
  """

  @typep key() :: term()
  @typep value() :: term()
  @opaque t() :: nil | {key(), value(), t(), t()}

  @spec new() :: t()
  def new, do: nil

  @spec insert(t(), key(), value()) :: t()
  def insert(nil, key, value), do: {key, value, nil, nil}

  def insert({k, v, smaller, larger}, key, value) when key < k,
    do: {k, v, insert(smaller, key, value), larger}

  def insert({k, v, smaller, larger}, key, value) when key > k,
    do: {k, v, smaller, insert(larger, key, value)}

  def insert({_k, _v, smaller, larger}, key, value), do: {key, value, smaller, larger}

  @spec delete(t(), key()) :: t()
  def delete(nil, _key), do: nil

  def delete({k, v, smaller, larger}, key) when key < k, do: {k, v, delete(smaller, key), larger}

  def delete({k, v, smaller, larger}, key) when key > k, do: {k, v, smaller, delete(larger, key)}

  def delete({key, _value, smaller, larger}, key), do: merge(smaller, larger)

  @spec lookup(t(), key()) :: {:ok, value()} | :not_found
  def lookup(nil, _key), do: :not_found

  def lookup({k, _v, smaller, _larger}, key) when key < k, do: lookup(smaller, key)

  def lookup({k, _v, _smaller, larger}, key) when key > k, do: lookup(larger, key)

  def lookup({key, value, _smaller, _larger}, key), do: {:ok, value}

  @spec next(t(), key() | nil) :: {:ok, key(), value()} | :none
  def next(tree, key) do
    tree
    |> stream_forward(key)
    |> Stream.drop_while(fn {k, _v} -> not is_nil(key) and key >= k end)
    |> Enum.at(0)
    |> case do
      nil -> :none
      {key, value} -> {:ok, key, value}
    end
  end

  @spec prev(t(), key() | nil) :: {:ok, key(), value()} | :none
  def prev(tree, key) do
    tree
    |> stream_backward(key)
    |> Stream.drop_while(fn {k, _v} -> not is_nil(key) and key <= k end)
    |> Enum.at(0)
    |> case do
      nil -> :none
      {key, value} -> {:ok, key, value}
    end
  end

  @spec stream_forward(t(), key() | nil) :: Enumerable.t()
  def stream_forward(tree, key \\ nil)

  def stream_forward(tree, key) do
    stream =
      Stream.resource(
        fn -> [{:tree, tree}] end,
        fn
          [] ->
            {:halt, []}

          [{:elem, key, value} | rest] ->
            {[{key, value}], rest}

          [{:tree, {key, value, smallest, largest}} | rest] ->
            {[], [{:tree, smallest}, {:elem, key, value}, {:tree, largest} | rest]}

          [{:tree, nil} | rest] ->
            {[], rest}
        end,
        fn _val -> :ok end
      )

    Stream.drop_while(stream, fn {k, _v} -> not is_nil(key) and key > k end)
  end

  @spec stream_backward(t(), key() | nil) :: Enumerable.t()
  def stream_backward(tree, key \\ nil)

  def stream_backward(tree, key) do
    stream =
      Stream.resource(
        fn -> [{:tree, tree}] end,
        fn
          [] ->
            {:halt, []}

          [{:elem, key, value} | rest] ->
            {[{key, value}], rest}

          [{:tree, {key, value, smallest, largest}} | rest] ->
            {[], [{:tree, largest}, {:elem, key, value}, {:tree, smallest} | rest]}

          [{:tree, nil} | rest] ->
            {[], rest}
        end,
        fn _val -> :ok end
      )

    Stream.drop_while(stream, fn {k, _v} -> not is_nil(key) and key < k end)
  end

  defp merge(nil, tree), do: tree
  defp merge(tree, nil), do: tree

  defp merge(smaller, larger) do
    {largest_key, largest_val, larger2} = take_smallest(larger)

    {largest_key, largest_val, smaller, larger2}
  end

  defp take_smallest({key, value, nil, larger}), do: {key, value, larger}

  defp take_smallest({key, value, smaller, larger}) do
    {smallest_key, smallest_val, smaller2} = take_smallest(smaller)

    {smallest_key, smallest_val, {key, value, smaller2, larger}}
  end
end
