defmodule AeMdw.Migrations.LogsByIndex do
  @moduledoc """
  Reindexes event logs by call txi and log index.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    write_mutations =
      state
      |> Collection.stream(Model.IdxContractLog, nil)
      |> Stream.map(&State.fetch!(state, Model.IdxContractLog, &1))
      |> Enum.map(fn Model.idx_contract_log(index: {call_txi, create_txi, evt_hash, log_idx}) ->
        WriteMutation.new(
          Model.IdxContractLog,
          Model.idx_contract_log(index: {call_txi, log_idx, create_txi, evt_hash})
        )
      end)

    delete_mutation =
      DeleteKeysMutation.new(%{Model.IdxContractLog => Database.all_keys(Model.IdxContractLog)})

    mutations = [delete_mutation | write_mutations]

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
