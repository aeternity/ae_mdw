defmodule AeMdw.Migrations.ClearStaleInactiveNamesInAuction do
  @moduledoc """
  Archives the InactiveName of names that are currently being auctioned again
  into PreviousName, so lookups return the live auction.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Names

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {write_mutations, delete_keys} =
      state
      |> Collection.stream(Model.AuctionBid, nil)
      |> Stream.map(&State.get(state, Model.InactiveName, &1))
      |> Stream.filter(&match?({:ok, _inactive_name}, &1))
      |> Enum.reduce({[], %{}}, fn {:ok, inactive_name}, {write_mutations, delete_keys} ->
        Model.name(index: plain_name, active: active, owner: owner_pk) = inactive_name
        expire = Names.revoke_or_expire_height(inactive_name)
        prev_name = Model.previous_name(index: {plain_name, active}, name: inactive_name)

        delete_keys =
          delete_keys
          |> Map.update(Model.InactiveName, [plain_name], &[plain_name | &1])
          |> Map.update(
            Model.InactiveNameOwner,
            [{owner_pk, plain_name}],
            &[{owner_pk, plain_name} | &1]
          )
          |> Map.update(
            Model.InactiveNameExpiration,
            [{expire, plain_name}],
            &[{expire, plain_name} | &1]
          )
          |> Map.update(
            Model.InactiveNameOwnerDeactivation,
            [{owner_pk, expire, plain_name}],
            &[{owner_pk, expire, plain_name} | &1]
          )

        {[WriteMutation.new(Model.PreviousName, prev_name) | write_mutations], delete_keys}
      end)

    _state =
      if write_mutations == [] do
        state
      else
        State.commit_db(state, [DeleteKeysMutation.new(delete_keys) | write_mutations])
      end

    {:ok, length(write_mutations)}
  end
end
