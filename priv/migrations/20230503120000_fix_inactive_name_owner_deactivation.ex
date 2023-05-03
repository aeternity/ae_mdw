defmodule AeMdw.Migrations.FixInactiveNameOwnerDeactivation do
  @moduledoc """
  Deletes no longer valid InactiveNameOwnerDeactivation keys.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    invalid_deactivations =
      state
      |> Collection.stream(Model.InactiveNameOwnerDeactivation, nil)
      |> Stream.filter(fn {_owner_pk, expire, plain_name} ->
        not State.exists?(state, Model.InactiveNameExpiration, {expire, plain_name})
      end)
      |> Enum.to_list()

    mutation =
      DeleteKeysMutation.new(%{Model.InactiveNameOwnerDeactivation => invalid_deactivations})

    _new_state = State.commit(state, [mutation])

    {:ok, length(invalid_deactivations)}
  end
end
