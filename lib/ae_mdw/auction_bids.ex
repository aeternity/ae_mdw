defmodule AeMdw.AuctionBids do
  @moduledoc """
  Context module for dealing with AuctionBids.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
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
    case bid_top_key(plain_name) do
      {:ok, auction_bid_key} ->
        {:ok, render(auction_bid_key, expand?)}

      :not_found ->
        :not_found
    end
  end

  @spec fetch_auctions(direction(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[auction_bid()], cursor() | nil}
  def fetch_auctions(direction, :name, cursor, limit, expand?) do
    cursor =
      case cursor do
        nil ->
          nil

        plain_name ->
          case bid_top_key(plain_name) do
            {:ok, key} -> key
            :not_found -> nil
          end
      end

    {auction_bid_keys, next_cursor} = Mnesia.fetch_keys(@table, direction, cursor, limit)

    auction_bids = Enum.map(auction_bid_keys, &render(&1, expand?))

    {auction_bids, serialize_auction_bid_cursor(next_cursor)}
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
         {plain_name, {_bid_height, _txi}, expire_height, _owner_pk,
          [{_last_bid_bi, last_bid_txi} | _rest_bids] = bids},
         _expand?
       ) do
    last_bid = Txs.fetch!(last_bid_txi)
    name_ttl = Name.expire_after(expire_height)

    %{
      name: plain_name,
      status: "auction",
      active: false,
      info: %{
        auction_end: expire_height,
        last_bid: put_in(last_bid, ["tx", "ttl"], name_ttl),
        bids: Enum.map(bids, &bi_txi_txi/1)
      },
      previous: Names.fetch_previous_list(plain_name)
    }
  end

  defp bid_top_key(plain_name) do
    top_key = {plain_name, <<>>, <<>>, <<>>, <<>>}

    case Mnesia.prev_key(@table, top_key) do
      {:ok, auction_bid_key} ->
        if elem(auction_bid_key, 0) == plain_name do
          {:ok, auction_bid_key}
        else
          :not_found
        end

      :none ->
        :not_found
    end
  end

  defp bi_txi_txi({{_height, _mbi}, txi}), do: txi

  defp serialize_auction_bid_cursor(nil), do: nil

  defp serialize_auction_bid_cursor({plain_name, _block_index, _expire, _owner_pk, _bids}),
    do: plain_name

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
