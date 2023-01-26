import Config

#
# Telemetry
#
period = String.to_integer(System.get_env("TELEMETRY_POLLER_PERIOD") || "10000")

config :ae_mdw, AeMdw.APM.TelemetryPoller, period: period

if config_env() == :prod do
  host = System.get_env("TELEMETRY_STATSD_HOST") || "datadog_statsd"
  port = String.to_integer(System.get_env("TELEMETRY_STATSD_PORT") || "8125")
  formatter = System.get_env("TELEMETRY_STATSD_FORMAT") || "datadog"

  config :ae_mdw, TelemetryMetricsStatsd,
    formatter: String.to_atom(formatter),
    host: host,
    port: port
end
