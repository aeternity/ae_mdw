import Config

env = config_env()

config :ae_mdw, :wealth_rank_size, String.to_integer(System.get_env("WEALTH_RANK_SIZE", "200"))

#
# Telemetry
#
period = String.to_integer(System.get_env("TELEMETRY_POLLER_PERIOD") || "10000")

config :ae_mdw, AeMdw.APM.TelemetryPoller, period: period

config :ae_mdw, :enable_v3?, true
config :ae_mdw, memstore_lifetime_secs: 60

ip =
  if System.get_env("DISABLE_IPV6", "false") in ["true", "1"] do
    {0, 0, 0, 0}
  else
    {0, 0, 0, 0, 0, 0, 0, 0}
  end

# Endpoint
if env != :test do
  port = String.to_integer(System.get_env("PORT") || "4000")
  protocol_opts = [max_request_line_length: 1_024, max_skip_body_length: 1_024]

  config :ae_mdw, AeMdwWeb.Endpoint,
    http: [
      ip: ip,
      port: port,
      protocol_options: protocol_opts
    ],
    debug_errors: env == :dev,
    cache_static_manifest: "priv/static/cache_manifest.json"

  ws_port = String.to_integer(System.get_env("WS_PORT") || "4001")
  timeout_opts = [inactivity_timeout: 30 * 60_000, idle_timeout: 30 * 60_000]

  config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
    http: [
      ip: ip,
      port: ws_port,
      protocol_options: protocol_opts ++ timeout_opts
    ]
end

# Logging

log_level =
  case System.get_env("LOG_LEVEL") do
    "none" -> :none
    "emergency" -> :emergency
    "alert" -> :alert
    "critical" -> :critical
    "error" -> :error
    "warning" -> :warning
    "notice" -> :notice
    "info" -> :info
    "debug" -> :debug
    _level -> nil
  end

enable_json_log = System.get_env("ENABLE_JSON_LOG", "false") in ["true", "1"]
enable_console_log = System.get_env("ENABLE_CONSOLE_LOG", "false") in ["true", "1"]

base_logger_backends = Application.get_env(:logger, :backends, [])

logger_backends =
  if enable_console_log, do: [:console | base_logger_backends], else: base_logger_backends

formatters = %{
  "datadog" => :datadog,
  "standard" => :standard
}

if env in [:test, :prod] do
  if System.get_env("ENABLE_TELEMETRY", "false") in ["true", "1"] do
    {:ok, hostname} = :inet.gethostname()
    host = System.get_env("TELEMETRY_STATSD_HOST") || to_string(hostname)
    port = String.to_integer(System.get_env("TELEMETRY_STATSD_PORT", "8125"))
    formatter_str = System.get_env("TELEMETRY_STATSD_FORMAT", "datadog")
    formatter = Map.fetch!(formatters, formatter_str)

    config :ae_mdw, TelemetryMetricsStatsd,
      formatter: formatter,
      host: host,
      port: port
  end

  if enable_json_log do
    logger_backends = [LoggerJSON | logger_backends]

    config :logger,
      level: log_level || :info,
      backends: logger_backends

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
    config :phoenix, :serve_endpoints, true
  end

  config :logger,
    level: log_level || :info,
    backends: logger_backends
end
