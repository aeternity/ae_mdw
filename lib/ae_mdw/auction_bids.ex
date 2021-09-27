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

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type auction_bid() :: term()

  @typep order_by :: :expiration | :name
  @typep limit :: Mnesia.limit()
  @typep direction :: Mnesia.direction()
  @typep plain_name() :: binary()

  @table Model.AuctionBid
  @table_expiration Model.AuctionExpiration

  @spec top_auction_bid(plain_name(), boolean()) :: {:ok, auction_bid()} | :not_found
  def top_auction_bid(plain_name, expand?) do
    case Mnesia.prev_key(@table, bid_top_key(plain_name)) do
      {:ok, auction_bid} ->
        if(elem(auction_bid, 0) == plain_name,
          do: {:ok, render(auction_bid, expand?)},
          else: :not_found
        )

      :none ->
        :not_found
    end
  end

  @spec fetch_auctions(direction(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[auction_bid()], cursor() | nil}
  def fetch_auctions(direction, :name, cursor, limit, expand?) do
    {name_keys, next_cursor} =
      Mnesia.fetch_keys(@table, direction, deserialize_name_cursor(cursor), limit)

    auction_bids =
      Enum.map(name_keys, fn plain_name ->
        auction_bid = Mnesia.fetch!(@table, plain_name)

        render(auction_bid, expand?)
      end)

    {auction_bids, serialize_name_cursor(next_cursor)}
  end

  def fetch_auctions(direction, :expiration, cursor, limit, expand?) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(@table_expiration, direction, deserialize_exp_cursor(cursor), limit)

    auction_bids =
      Enum.map(exp_keys, fn {_exp, plain_name} ->
        {:ok, auction_bid} = top_auction_bid(plain_name, expand?)

        auction_bid
      end)

    {auction_bids, serialize_exp_cursor(next_cursor)}
  end

  defp render(
         {plain_name, {_block_index, _txi}, expire_height, _owner_pk,
          [{_last_bid_bi, last_bid_txi} | _rest_bids] = bids},
         _expand?
       ) do
    %{
      name: plain_name,
      status: "auction",
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

  defp serialize_name_cursor(name), do: name

  defp deserialize_name_cursor(cursor), do: cursor

  defp serialize_exp_cursor(nil), do: nil

  defp serialize_exp_cursor({exp_height, name}), do: "#{exp_height}-#{name}"

  defp deserialize_exp_cursor(nil), do: nil

  defp deserialize_exp_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin) do
      [_match0, exp_height, name] -> {String.to_integer(exp_height), name}
      nil -> nil
    end
  end
end
