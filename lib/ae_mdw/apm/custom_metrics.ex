defmodule AeMdw.Apm.CustomMetrics do
  @moduledoc false

  alias AeMdw.Db.State
  alias AeMdw.Db.Status

  @spec dispatch_status() :: :ok
  def dispatch_status do
    status = Status.node_and_mdw_status(State.mem_state())
    :telemetry.execute([:ae_mdw, :status], status, %{})
  end
end
