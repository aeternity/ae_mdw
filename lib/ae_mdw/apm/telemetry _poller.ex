defmodule AeMdw.APM.TelemetryPoller do
  @moduledoc false

  alias AeMdw.Db.State
  alias AeMdw.Db.Status

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

  @spec dispatch_status() :: :ok
  def dispatch_status do
    :telemetry.execute([:ae_mdw, :status], Status.node_and_mdw_status(State.mem_state()))
  end

  defp periodic_measurements do
    [
      {:process_info,
       name: :ae_mdw_worker,
       event: [:ae_mdw, :worker],
       keys: [:memory, :message_queue_len, :system_counts]},
      {__MODULE__, :dispatch_status, []}
    ]
  end
end
