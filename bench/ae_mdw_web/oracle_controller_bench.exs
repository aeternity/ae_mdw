defmodule AeMdw.OracleControllerBench do
  import Phoenix.ConnTest

  @endpoint AeMdwWeb.Endpoint

  def active_oracles do
    build_conn()
    |> get("/oracles/active?direction=forward")
  end

  def inactive_oracles do
    build_conn()
    |> get("/oracles/inactive?direction=forward")
  end

  def oracles do
    build_conn()
    |> get("/oracles")
  end

  def oracles_v2 do
    build_conn()
    |> get("/v2/oracles")
  end
end

Benchee.run(
  %{
    active_oracles: &AeMdw.OracleControllerBench.active_oracles/0
  },
  memory_time: 1
)

Benchee.run(
  %{
    inactive_oracles: &AeMdw.OracleControllerBench.inactive_oracles/0
  },
  memory_time: 1
)

Benchee.run(
  %{
    oracles: &AeMdw.OracleControllerBench.oracles/0
  },
  memory_time: 1
)
