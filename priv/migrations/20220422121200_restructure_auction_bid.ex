defmodule AeMdw.Migrations.RestructureAuctionBidn do
  @moduledoc """
  Restructure auction bids to use a simple plain name index.
  """

  alias AeMdw.Database
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()
    keys = Database.all_keys(Model.AuctionBid)
    indexed_count = length(keys)

    write_mutations =
      Enum.map(keys, fn {plain_name, block_index_txi, expire_height, owner, bids} ->
        auction_bid =
          Model.auction_bid(
            index: plain_name,
            block_index_txi: block_index_txi,
            expire_height: expire_height,
            owner: owner,
            bids: bids
          )

        WriteMutation.new(Model.AuctionBid, auction_bid)
      end)

    mutations = [DeleteKeysMutation.new(%{Model.AuctionBid => keys}) | write_mutations]

    State.commit(State.new(), mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
