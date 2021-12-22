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

    Stream.resource(
      fn ->
        empty_count = Semaphore.new(0)
        full_count = Semaphore.new(buffer_size)
        {:ok, agent} = Agent.start(fn -> :queue.new() end)

        task =
          Task.async(fn ->
            produce_results(enumerable, fun, empty_count, full_count, agent)
          end)

        {task, empty_count, full_count, agent}
      end,
      fn {_task, empty_count, full_count, agent} = state ->
        # CONSUMER
        Semaphore.wait(empty_count)

        result = pop_agent_item(agent)

        Semaphore.signal(full_count)

        case result do
          {:ok, item} -> {[item], state}
          :ended -> {:halt, state}
        end
      end,
      fn {task, empty_count, full_count, agent} ->
        Semaphore.stop(empty_count)
        Semaphore.stop(full_count)
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

  defp produce_results(enumerable, fun, empty_count, full_count, agent) do
    Enum.each(enumerable, fn entry ->
      # PRODUCER
      Semaphore.wait(full_count)

      push_agent_item(agent, fun.(entry))

      Semaphore.signal(empty_count)
    end)

    Agent.update(agent, fn _queue -> :ended end)
  end
end
