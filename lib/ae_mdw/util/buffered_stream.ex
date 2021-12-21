defmodule AeMdw.Util.BufferedStream do
  @moduledoc """
  Producer/consumer implementation of a preloading stream, with a limited buffer
  size.
  """

  alias AeMdw.Util.Semaphore

  @type opt() :: {:buffer_size, pos_integer()}

  @spec map(Enumerable.t(), (Enum.element() -> any()), [opt()]) :: Enumerable.t()
  def map(enumerable, fun, opts) do
    buffer_size = Keyword.fetch!(opts, :buffer_size)
    empty_count = Semaphore.new(0)
    full_count = Semaphore.new(buffer_size)
    processing = Semaphore.new(1)
    {:ok, agent} = Agent.start(fn -> :queue.new() end)

    task =
      Task.async(fn ->
        Enum.each(enumerable, fn entry ->
          # PRODUCER
          Semaphore.wait(full_count)
          Semaphore.wait(processing)

          push_agent_item(agent, fun.(entry))

          Semaphore.signal(processing)
          Semaphore.signal(empty_count)
        end)

        Agent.update(agent, fn _queue -> :ended end)
      end)

    Stream.resource(
      fn -> :ok end,
      fn state ->
        # CONSUMER
        Semaphore.wait(empty_count)

        result = pop_agent_item(agent)

        Semaphore.signal(full_count)

        case result do
          {:ok, item} -> {[item], state}
          :ended -> {:halt, state}
        end
      end,
      fn _state ->
        Semaphore.stop(empty_count)
        Semaphore.stop(full_count)
        Semaphore.stop(processing)
        Agent.stop(agent)
        Task.shutdown(task)
      end
    )
  end

  defp push_agent_item(agent, item) do
    Agent.update(agent, fn queue -> :queue.in(item, queue) end)
  end

  defp pop_agent_item(agent) do
    Agent.get_and_update(agent, fn
      :ended ->
        {:ended, :ended}

      queue ->
        {{:value, item}, new_queue} = :queue.out(queue)

        {{:ok, item}, new_queue}
    end)
  end
end
