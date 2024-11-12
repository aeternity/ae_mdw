defmodule AeMdw.Util.SortedTable do
  @moduledoc """
  Table of key-value elements iterable in both directions (next and prev).
  """

  @typep key() :: term()
  @typep value() :: term()
  @opaque t() :: :ets.tid()

  @eot :"$end_of_table"

  @spec new() :: t()
  def new(),
    do:
      :ets.new(:table, [
        :ordered_set,
        :public,
        {:write_concurrency, false},
        {:read_concurrency, true}
      ])

  @spec delete(t()) :: :ok
  def delete(t) do
    :ets.delete(t)
    :ok
  end

  @spec insert(t(), key(), value()) :: t()
  def insert(t, key, value) do
    :ets.insert(t, {key, value})
    t
  end

  @spec delete(t(), key()) :: t()
  def delete(t, key) do
    :ets.delete(t, key)
    t
  end

  @spec lookup(t(), key()) :: {:ok, value()} | :not_found
  def lookup(t, key) do
    case :ets.lookup(t, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :not_found
    end
  end

  @spec next(t(), key() | nil) :: {:ok, key(), value()} | :none
  def next(t, key) do
    case :ets.next(t, key || -1) do
      @eot -> :none
      key -> {:ok, key, :ets.lookup_element(t, key, 2)}
    end
  end

  @spec prev(t(), key() | nil) :: {:ok, key(), value()} | :none
  def prev(t, nil) do
    case :ets.last(t) do
      @eot -> :none
      key -> {:ok, key, :ets.lookup_element(t, key, 2)}
    end
  end

  def prev(t, key) do
    case :ets.prev(t, key) do
      @eot -> :none
      key -> {:ok, key, :ets.lookup_element(t, key, 2)}
    end
  end

  @spec stream_forward(t()) :: Enumerable.t()
  def stream_forward(t) do
    Stream.unfold(next(t, -1), fn
      :none -> nil
      {:ok, key, value} -> {{key, value}, next(t, key)}
    end)
  end
end
