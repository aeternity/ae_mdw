defmodule AeMdwWeb.Benchmark.Aggregator do
  alias AeMdwWeb.Benchmark.Worker

  def spawn_process(n), do: spawn_process(n, [])

  def spawn_process(0, acc), do: acc

  def spawn_process(n, acc) do
    {:ok, pid} = Worker.start(%{})
    spawn_process(n - 1, [pid | acc])
  end

  def execute(scenario, pids) do
    Enum.each(pids, fn pid ->
      Worker.prepare(pid, Enum.shuffle(scenario))
    end)

    states = for p <- pids, do: Worker.state(p)

    for path <- scenario, into: %{} do
      {path, extract_values(states, path, %{status: [], time: []})}
    end
  end

  def extract_values([], _, acc), do: acc

  def extract_values([h | t], key, acc) do
    time = h[key].time
    status = h[key].status
    extract_values(t, key, status: [status | acc[:status]], time: [time | acc[:time]])
  end
end
