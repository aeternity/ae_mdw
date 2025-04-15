defmodule AeMdw.Migrations.InitialCountOfAccountCounters do
  alias AeMdw.Db.State

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(_state, _from_start?) do
  end
end
