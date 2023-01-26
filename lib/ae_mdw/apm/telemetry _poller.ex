defmodule AeMdw.APM.TelemetryPoller do
  @moduledoc false

  @spec child_spec([]) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @spec start_link([]) :: Supervisor.on_start()
  def start_link([]) do
    [period: period] = Application.get_env(:ae_mdw, __MODULE__)

    :telemetry_poller.start_link(
      measurements: periodic_measurements(),
      period: period,
      name: __MODULE__
    )
  end

  defp periodic_measurements do
    [
      {AeMdw.Apm.CustomMetrics, :dispatch_status, []},
      {:process_info,
       name: :ae_mdw_worker,
       event: [:ae_mdw, :worker],
       keys: [:memory, :message_queue_len, :system_counts]}
    ]
  end
end
