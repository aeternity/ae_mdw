defmodule AeMdw.Migrations.RestructureAexnInvalidContracts do
  @moduledoc """
  Generate block difficulty statistics.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  import Record

  defrecord :aexn_invalid_contract, [:index, :reason]

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    state
    |> Collection.stream(Model.AexnInvalidContract, nil)
    |> Stream.map(&State.fetch!(state, Model.AexnInvalidContract, &1))
    |> Stream.filter(&match?(aexn_invalid_contract(), &1))
    |> Stream.map(fn aexn_invalid_contract(
                       index: index,
                       reason: reason
                     ) ->
      WriteMutation.new(
        Model.AexnInvalidContract,
        Model.aexn_invalid_contract(index: index, reason: reason, description: "unknown")
      )
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _new_state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end
