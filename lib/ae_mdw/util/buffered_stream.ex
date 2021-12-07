defmodule AeMdw.Util.BufferedStream do
  @moduledoc """
  Producer/consumer implementation of a preloading stream, with a limited buffer
  size.
  """

  alias AeMdw.Util.Semaphore

  @spec map(Enumerable.t(), (Enum.element() -> any()), pos_integer()) :: Enumerable.t()
  def map(enumerable, fun, buffer_size) do
    empty_count = Semaphore.new(0)
    full_count = Semaphore.new(buffer_size)
    processing = Semaphore.new(1)

    enumerable
    |> Task.async_stream(
      fn entry ->
        # PRODUCER
        Semaphore.wait(full_count)
        Semaphore.wait(processing)

        result = fun.(entry)

        Semaphore.signal(processing)
        Semaphore.signal(empty_count)

        result
      end,
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, result} ->
      # CONSUMER
      Semaphore.wait(empty_count)
      Semaphore.signal(full_count)

      result
    end)
  end
end
