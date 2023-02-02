import Config

#
# Telemetry
#
period = String.to_integer(System.get_env("TELEMETRY_POLLER_PERIOD") || "10000")

config :ae_mdw, AeMdw.APM.TelemetryPoller, period: period

if config_env() in [:test, :prod] do
  if System.get_env("ENABLE_TELEMETRY", "false") in ["true", "1"] do
    {:ok, hostname} = :inet.gethostname()
    host = System.get_env("TELEMETRY_STATSD_HOST") || to_string(hostname)
    port = String.to_integer(System.get_env("TELEMETRY_STATSD_PORT", "8125"))
    formatter = System.get_env("TELEMETRY_STATSD_FORMAT", "datadog")

    config :ae_mdw, TelemetryMetricsStatsd,
      formatter: String.to_atom(formatter),
      host: host,
      port: port
  end

  if System.get_env("ENABLE_JSON_LOG", "false") in ["true", "1"] do
    config :logger,
      level: :info,
      backends: [LoggerJSON]

    formatter = System.get_env("JSON_LOG_FORMAT", "datadog")
    opts = [metadata: [:request_id], json_encoder: Jason]

    datadog_opts = [
      metadata_formatter: LoggerJSON.Plug.MetadataFormatters.DatadogLogger,
      formatter: LoggerJSON.Formatters.DatadogLogger
    ]

    opts = if formatter == "datadog", do: opts ++ datadog_opts, else: opts

    config :logger_json, :backend, opts
  end
end
