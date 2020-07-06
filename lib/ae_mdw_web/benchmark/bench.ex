defmodule Client do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/"
  plug Tesla.Middleware.Headers, [{"authorization", "token xyz"}]
  plug Tesla.Middleware.JSON

  def build_request(path) do
    get(path)
  end
end

defmodule Mix.Tasks.Bench do
  use Mix.Task

  @default_simultaneous_requests_number 10
  @default_paths [
    "/txi/87450",
    "/txs/count",
    "/txs/count/ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
    "/txs/forward?type=channel_create&limit=1",
    "/txs/forward?type_group=oracle&limit=1",
    "/txs/forward?contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2",
    "/txs/forward?oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&limit=1",
    "/txs/forward?name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&limit=1",
    "/txs/forward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
    "/txs/backward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1",
    "/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&type_group=name",
    "/txs/gen/223000-223007?limit=30",
    "/txs/txi/509111",
    "/txs/txi/409222-501000?limit=30"
  ]

  def run(["default"]), do: run(@default_paths)

  def run(paths) when is_list(paths), do: run(paths, %{all_total_exec_time: 0})

  def run([req | paths], acc) do
    response = spawn_requests(req, @default_simultaneous_requests_number)
    status = calculate_status(response.status)

    data = "
          Path: #{inspect(response.req_path)}
          Number of requests: #{inspect(response.total_requests)}
          Successful requests: #{inspect(status.successful_requests)}
          Failed requests: #{inspect(status.failed_requests)}
          Total execution time: #{inspect(response.total_exec_time)} ms
          Min exec time: #{inspect(response.min)} ms
          Max exec time: #{inspect(response.max)} ms
          Average: #{inspect(response.average)} ms
          Mean: #{inspect(response.mean)} ms
          Percentiles:
            50th: #{inspect(response.percentiles["50th"])} ms
            80th: #{inspect(response.percentiles["80th"])} ms
            90th: #{inspect(response.percentiles["90th"])} ms
            99th: #{inspect(response.percentiles["99th"])} ms
          ......................................................................
          "
    Mix.shell().info(data)

    new_acc = %{acc | all_total_exec_time: acc.all_total_exec_time + response.total_exec_time}

    run(paths, new_acc)
  end

  def run([], acc) do
    info = "
      All tests execution time: #{inspect(acc.all_total_exec_time)} ms
      "

    Mix.shell().info(info)
  end

  def spawn_requests(path, n) do
    fun = fn -> Client.build_request(path) end

    acc = %{
      total_exec_time: 0,
      average: 0,
      mean: 0,
      min: 0,
      max: 0,
      percentiles: %{"50th" => 0, "80th" => 0, "90th" => 0, "99th" => 0},
      total_requests: n,
      all_times: [],
      req_path: path,
      status: []
    }

    spawn_requests(fun, n, acc)
  end

  def spawn_requests(_fun, 0, acc) do
    mean = (min(acc.all_times) + max(acc.all_times)) / 2

    %{
      acc
      | total_exec_time: acc.total_exec_time / 1000,
        mean: mean / 1000,
        min: min(acc.all_times) / 1000,
        max: max(acc.all_times) / 1000,
        average: acc.total_exec_time / acc.total_requests / 1000,
        percentiles: %{
          acc.percentiles
          | "50th" => percentile(acc.all_times, 50) / 1000,
            "80th" => percentile(acc.all_times, 80) / 1000,
            "90th" => percentile(acc.all_times, 90) / 1000,
            "99th" => percentile(acc.all_times, 99) / 1000
        }
    }
  end

  def spawn_requests(fun, n, acc) do
    {time, {:ok, %Tesla.Env{status: status}}} = :timer.tc(fun)

    new_acc = %{
      acc
      | total_exec_time: acc.total_exec_time + time,
        all_times: [time | acc.all_times],
        status: [status | acc.status]
    }

    spawn_requests(fun, n - 1, new_acc)
  end

  defp percentile([], _), do: nil
  defp percentile([x], _), do: x
  defp percentile(list, 0), do: min(list)
  defp percentile(list, 100), do: max(list)

  defp percentile(list, n) when is_list(list) and is_number(n) do
    s = Enum.sort(list)
    r = n / 100.0 * (length(list) - 1)
    f = :erlang.trunc(r)
    lower = Enum.at(s, f)
    upper = Enum.at(s, f + 1)
    lower + (upper - lower) * (r - f)
  end

  defp min([]), do: nil

  defp min(list) do
    Enum.min(list)
  end

  defp max([]), do: nil

  defp max(list) do
    Enum.max(list)
  end

  defp calculate_status(list) do
    Enum.reduce(list, %{successful_requests: 0, failed_requests: 0}, fn
      200, acc ->
        %{acc | successful_requests: acc[:successful_requests] + 1}

      _, acc ->
        %{acc | failed_requests: acc[:failed_requests] + 1}
    end)
  end
end
