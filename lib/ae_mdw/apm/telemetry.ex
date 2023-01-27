defmodule AeMdw.APM.Telemetry do
  @moduledoc false
  use Supervisor

  import Telemetry.Metrics

  @spec start_link([]) :: Supervisor.on_start()
  def start_link([]) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    statsd_config = Application.get_env(:ae_mdw, TelemetryMetricsStatsd, [])
    host = Keyword.fetch!(statsd_config, :host)
    port = Keyword.fetch!(statsd_config, :port)
    formatter = Keyword.get(statsd_config, :formatter, :standard)

    children = [
      AeMdw.APM.TelemetryPoller,
      {TelemetryMetricsStatsd, metrics: metrics(), host: host, port: port, formatter: formatter}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    [
      # Middleware Metrics
      distribution("ae_mdw.status.mdw_gens_per_minute"),
      last_value("ae_mdw.status.mdw_height"),
      last_value("ae_mdw.status.mdw_syncing"),
      last_value("ae_mdw.status.node_height"),
      last_value("ae_mdw.status.node_progress"),
      counter("ae_mdw.error.status",
        tags: [:request_path, :query_params, :reason]
      ),

      # Phoenix Metrics
      distribution("phoenix.endpoint.stop.duration",
        tags: [:request_path],
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.stop.duration",
        tags: [:route]
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Time Metrics
      # summary("my_app.repo.query.total_time", unit: {:native, :millisecond}),
      # summary("my_app.repo.query.query_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.memory.ets", unit: {:byte, :megabyte}),
      summary("vm.memory.processes", unit: {:byte, :megabyte}),
      summary("vm.memory.system", unit: {:byte, :megabyte}),
      summary("vm.memory.atom", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      summary("vm.system_counts.port_count"),
      summary("vm.system_counts.process_count")
    ]
  end
end
