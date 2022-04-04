defmodule AeMdw.Migrations.RecalculateAex9Balance do
  @moduledoc """
  Updates .
  """
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), pos_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    all_keys = Database.all_keys(Model.Aex9Balance)

    State.commit(State.new(), [
      AeMdw.Db.DeleteKeysMutation.new(%{Model.Aex9Balance => all_keys})
    ])

    indexing_count =
      all_keys
      |> Enum.map(fn {contract_pk, _account_pk} -> contract_pk end)
      |> Enum.uniq()
      |> Enum.map(fn contract_pk ->
        AsyncTasks.Producer.enqueue(:update_aex9_state, [contract_pk])
      end)
      |> Enum.count()

    AsyncTasks.Producer.commit_enqueued()

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Async indexation scheduled for #{indexing_count} contracts in #{duration}s")

    {:ok, {indexing_count, duration}}
  end
end
