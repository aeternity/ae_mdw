defmodule AeMdw.Migrations.UpdateNameOwnersDeactivationIndex do
  @moduledoc """
  Updates owner names deactivations index to contemplate name transfers and updates which weren't taking into account before.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    active_mutations =
      state
      |> Collection.stream(Model.ActiveNameExpiration, nil)
      |> Enum.map(fn {deactivation_height, plain_name} ->
        Model.name(owner: owner_pk) = State.fetch!(state, Model.ActiveName, plain_name)

        owner_deactivation =
          Model.owner_deactivation(index: {owner_pk, deactivation_height, plain_name})

        WriteMutation.new(Model.ActiveNameOwnerDeactivation, owner_deactivation)
      end)

    inactive_mutations =
      state
      |> Collection.stream(Model.InactiveNameExpiration, nil)
      |> Enum.map(fn {deactivation_height, plain_name} ->
        Model.name(owner: owner_pk) = State.fetch!(state, Model.InactiveName, plain_name)

        owner_deactivation =
          Model.owner_deactivation(index: {owner_pk, deactivation_height, plain_name})

        WriteMutation.new(Model.InactiveNameOwnerDeactivation, owner_deactivation)
      end)

    mutations = active_mutations ++ inactive_mutations

    IO.puts("Executing #{length(mutations)} mutations on database")

    _state = State.commit(state, mutations)

    IO.puts("Done.")

    {:ok, length(mutations)}
  end
end
