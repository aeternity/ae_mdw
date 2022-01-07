defmodule AeMdw.AuctionBids do
  @moduledoc """
  Context module for dealing with AuctionBids.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Database
  alias AeMdw.Collection
  alias AeMdw.Names
  alias AeMdw.Txs

  require Model

  @table Model.AuctionBid

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type auction_bid() :: term()

  @typep order_by :: :expiration | :name
  @typep plain_name() :: Names.plain_name()
  @typep prefix() :: plain_name()
  @typep direction() :: Database.direction()
  @typep pagination() :: Collection.direction_limit()
  @typep names_scope() :: {prefix(), prefix()}

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

  @spec fetch!(plain_name(), boolean()) :: auction_bid()
  def fetch!(plain_name, expand?) do
    {:ok, auction_bid} = top_auction_bid(plain_name, expand?)

    auction_bid
  end

  @spec fetch_auctions(pagination(), order_by(), cursor() | nil, boolean()) ::
          {cursor() | nil, [auction_bid()], cursor() | nil}
  def fetch_auctions(pagination, :name, cursor, expand?) do
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

    {prev_cursor, auction_bids, next_cursor} =
      Collection.paginate(&Collection.stream(@table, &1, nil, cursor), pagination)

    {serialize_auction_bid_cursor(prev_cursor), Enum.map(auction_bids, &render(&1, expand?)),
     serialize_auction_bid_cursor(next_cursor)}
  end

  def fetch_auctions(pagination, :expiration, cursor, expand?) do
    cursor = deserialize_exp_cursor(cursor)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(&Collection.stream(@table_expiration, &1, nil, cursor), pagination)

    auction_bids =
      Enum.map(exp_keys, fn {_exp, plain_name} ->
        {:ok, auction_bid} = top_auction_bid(plain_name, expand?)

        auction_bid
      end)

    {serialize_exp_cursor(prev_cursor), auction_bids, serialize_exp_cursor(next_cursor)}
  end

  @spec auctions_stream(prefix(), direction(), names_scope(), cursor()) :: Enumerable.t()
  def auctions_stream(prefix, direction, {first_name, last_name}, cursor) do
    scope = {{first_name, nil, nil, nil, nil}, {last_name, "", nil, nil, nil}}
    cursor = if cursor, do: {cursor, nil, nil, nil, nil}

    @table
    |> Collection.stream(direction, scope, cursor)
    |> Stream.map(fn {plain_name, {_bid_height, _txi}, _expire_height, _owner_pk, _bids} ->
      plain_name
    end)
    |> Stream.take_while(&String.starts_with?(&1, prefix))
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

    case Database.prev_key(@table, top_key) do
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

  defp serialize_auction_bid_cursor(
         {{plain_name, _block_index, _expire, _owner_pk, _bids}, is_reversed?}
       ),
       do: {plain_name, is_reversed?}

  defp serialize_exp_cursor(nil), do: nil

  defp serialize_exp_cursor({{exp_height, name}, is_reversed?}),
    do: {"#{exp_height}-#{name}", is_reversed?}

  defp deserialize_exp_cursor(nil), do: nil

  defp deserialize_exp_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin) do
      [_match0, exp_height, name] -> {String.to_integer(exp_height), name}
      nil -> nil
    end
  end
end
