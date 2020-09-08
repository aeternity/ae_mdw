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

  alias AeMdwWeb.Benchmark.Aggregator

  @default_paths [
    "/txi/87450",
    "/tx/th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq",
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
    "/txs/txi/409222-501000?limit=30",
    "/names?limit=3",
    "/name/nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj",
    "/name/aeternity.chain",
    "/names/inactive?by=expiration&direction=forward&limit=1",
    "/names/active?by=name&limit=3",
    "/names/auctions",
    "/names/auctions?by=expiration&direction=forward&limit=2",
    "/name/pointers/wwwbeaconoidcom.chain",
    "/name/pointees/ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
    "/block/kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6",
    "/block/mh_25TNGuEkVGckfrH3rVwHiUsm2GFB17mKFEF3hYHR3zQrVXCRrp",
    "/blocki/300000",
    "/blocki/300001/2",
    "/blocks/backward?limit=1",
    "/blocks/forward?limit=2",
    "/blocks/100000-100100?limit=3"
  ]

  def run(arg) do
    pids = hd(arg) |> String.to_integer() |> Aggregator.spawn_process()
    info = Aggregator.execute(@default_paths, pids)

    Enum.each(info, fn {k, v} ->
      total_requests = hd(arg) |> String.to_integer()
      status = calculate_status(v[:status])
      total_exec_time = Enum.sum(v[:time]) / 1000
      min = min(v[:time]) / 1000
      max = max(v[:time]) / 1000
      average = total_exec_time / total_requests
      mean = (min + max) / 2

      percentiles = %{
        "50th" => percentile(v[:time], 50) / 1000,
        "80th" => percentile(v[:time], 80) / 1000,
        "90th" => percentile(v[:time], 90) / 1000,
        "99th" => percentile(v[:time], 99) / 1000
      }

      data = "
          Path: #{inspect(k)}
          Number of requests: #{inspect(total_requests)}
          Successful requests: #{inspect(status.successful_requests)}
          Failed requests: #{inspect(status.failed_requests)}
          Total execution time: #{inspect(total_exec_time)} ms
          Min exec time: #{inspect(min)} ms
          Max exec time: #{inspect(max)} ms
          Average: #{inspect(average)} ms
          Mean: #{inspect(mean)} ms
          Percentiles:
            50th: #{inspect(percentiles["50th"])} ms
            80th: #{inspect(percentiles["80th"])} ms
            90th: #{inspect(percentiles["90th"])} ms
            99th: #{inspect(percentiles["99th"])} ms
          ......................................................................
          "
      Mix.shell().info(data)
    end)
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
