defmodule AeMdw.Migrations.AddNameOwnersExpirationIndex do
  @moduledoc """
  Indexes owner names by expirations.
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
      |> Enum.map(fn {expiration_height, plain_name} ->
        Model.name(owner: owner_pk) = State.fetch!(state, Model.ActiveName, plain_name)

        owner_expiration =
          Model.owner_expiration(index: {owner_pk, expiration_height, plain_name})

        WriteMutation.new(Model.ActiveNameOwnerExpiration, owner_expiration)
      end)

    inactive_mutations =
      state
      |> Collection.stream(Model.InactiveNameExpiration, nil)
      |> Enum.map(fn {deactivation_height, plain_name} ->
        Model.name(owner: owner_pk) = State.fetch!(state, Model.InactiveName, plain_name)

        owner_expiration =
          Model.owner_expiration(index: {owner_pk, deactivation_height, plain_name})

        WriteMutation.new(Model.InactiveNameOwnerExpiration, owner_expiration)
      end)

    mutations = active_mutations ++ inactive_mutations

    IO.puts("Executing #{length(mutations)} mutations on database")

    _state = State.commit(state, mutations)

    IO.puts("Done.")

    {:ok, length(mutations)}
  end
end
