defmodule AeMdw.AuctionBids do
  @moduledoc """
  Context module for dealing with AuctionBids.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Names
  alias AeMdw.Txs

  require Model

  @table Model.AuctionBid

  @typep plain_name() :: binary()
  @typep auction_bid() :: term()

  @spec top_auction_bid(plain_name()) :: {:ok, auction_bid()} | :not_found
  def top_auction_bid(plain_name) do
    case Mnesia.prev_key(@table, bid_top_key(plain_name)) do
      {:ok, auction_bid} ->
        if(elem(auction_bid, 0) == plain_name, do: {:ok, render(auction_bid)}, else: :not_found)

      :none ->
        :not_found
    end
  end

  defp render(
         {plain_name, {_block_index, _txi}, expire_height, _owner_pk,
          [{_last_bid_bi, last_bid_txi} | _rest_bids] = bids}
       ) do
    %{
      name: plain_name,
      status: :auction,
      active: false,
      info: %{
        auction_end: expire_height,
        last_bid: Txs.fetch!(last_bid_txi),
        bids: Enum.map(bids, &bi_txi_txi/1)
      },
      previous: Names.fetch_previous_list(plain_name)
    }
  end

  defp bid_top_key(name), do: {name, <<>>, <<>>, <<>>, <<>>}

  defp bi_txi_txi({{_height, _mbi}, txi}), do: txi
end
