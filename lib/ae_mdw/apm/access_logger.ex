defmodule AeMdw.APM.AccessLogger do
  @moduledoc """
  Replaces Phoenix's default request logger so HTTP access lines are tagged
  and routed to their own log file/backend instead of mixing into the main
  application log (see config/runtime.exs for the matching backend split).
  """

  require Logger

  @spec attach() :: :ok
  def attach do
    # Phoenix.Logger's own handlers would otherwise duplicate these lines
    # untagged in the main log.
    :telemetry.detach({Phoenix.Logger, [:phoenix, :endpoint, :start]})
    :telemetry.detach({Phoenix.Logger, [:phoenix, :endpoint, :stop]})

    :telemetry.attach(
      {__MODULE__, [:phoenix, :endpoint, :stop]},
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      :ok
    )
  end

  @spec handle_event([atom()], map(), map(), term()) :: :ok
  def handle_event(_event, %{duration: duration}, %{conn: conn}, _config) do
    ms = System.convert_time_unit(duration, :native, :millisecond)

    Logger.info("#{conn.method} #{conn.request_path} -> #{conn.status} in #{ms}ms",
      mdw_access: true
    )
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
