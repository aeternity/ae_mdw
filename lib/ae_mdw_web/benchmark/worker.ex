defmodule AeMdwWeb.Benchmark.Worker do
  use GenServer

  def start(arg), do: GenServer.start(__MODULE__, arg)

  def state(pid), do: GenServer.call(pid, :state)

  def prepare(pid, scenario), do: GenServer.call(pid, {:start, scenario})

  def init(state) do
    {:ok, state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:start, scenario}, _from, _state) do
    new_state =
      Enum.reduce(scenario, %{}, fn url, acc ->
        fun = fn -> Client.build_request(url) end
        {time, {:ok, %Tesla.Env{status: status}}} = :timer.tc(fun)
        Map.put(acc, url, %{time: time, status: status})
      end)

    {:reply, new_state, new_state}
  end
end
