import Config

#
# Telemetry
#
period = String.to_integer(System.get_env("TELEMETRY_POLLER_PERIOD") || "10000")

config :ae_mdw, AeMdw.APM.TelemetryPoller, period: period

if config_env() in [:test, :prod] do
  {:ok, hostname} = :inet.gethostname()
  host = System.get_env("TELEMETRY_STATSD_HOST") || to_string(hostname)
  port = String.to_integer(System.get_env("TELEMETRY_STATSD_PORT") || "8125")
  formatter = System.get_env("TELEMETRY_STATSD_FORMAT") || "datadog"

  config :ae_mdw, TelemetryMetricsStatsd,
    formatter: String.to_atom(formatter),
    host: host,
    port: port
end
