import Config

env = config_env()

# Chain
config :aecore, network_id: System.get_env("NETWORK_ID", "ae_mainnet")

#
# Telemetry
#
period = String.to_integer(System.get_env("TELEMETRY_POLLER_PERIOD") || "10000")

config :ae_mdw, AeMdw.APM.TelemetryPoller, period: period

# Endpoint
port = String.to_integer(System.get_env("PORT") || "4000")
protocol_opts = [max_request_line_length: 1_024, max_skip_body_length: 1_024]

config :ae_mdw, AeMdwWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: port,
    protocol_options: protocol_opts
  ],
  debug_errors: env == :dev,
  cache_static_manifest: "priv/static/cache_manifest.json"

ws_port = String.to_integer(System.get_env("WS_PORT") || "4001")

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: ws_port,
    protocol_options: protocol_opts
  ]

if env in [:test, :prod] do
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

  if env == :prod do
    config :ae_mdw, AeMdwWeb.Endpoint, server: true
  end
end
