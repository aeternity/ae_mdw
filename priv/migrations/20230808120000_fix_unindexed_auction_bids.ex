defmodule AeMdw.Migrations.FixUnindexedAuctionBids do
  @moduledoc """
  Re-indexes expired auction bids claims.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {delete_keys, mutations} =
      state
      |> Collection.stream(Model.AuctionBidClaim, nil)
      |> Enum.reduce({[], []}, fn {plain_name, _height, _txi_idx} = key,
                                  {delete_keys, write_mutations} ->
        if State.exists?(state, Model.ActiveName, plain_name) do
          {
            [key | delete_keys],
            [WriteMutation.new(Model.NameClaim, Model.name_claim(index: key)) | write_mutations]
          }
        else
          {delete_keys, write_mutations}
        end
      end)

    mutations = [DeleteKeysMutation.new(%{Model.AuctionBidClaim => delete_keys}) | mutations]

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
