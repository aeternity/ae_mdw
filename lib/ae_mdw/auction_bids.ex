defmodule AeMdw.AuctionBids do
  @moduledoc """
  Context module for dealing with AuctionBids.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Database
  alias AeMdw.Collection
  alias AeMdw.Names
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type auction_bid() :: term()

  @typep opts() :: Util.opts()
  @typep state() :: State.t()
  @typep order_by :: :expiration | :name
  @typep plain_name() :: Names.plain_name()
  @typep prefix() :: plain_name()
  @typep direction() :: Database.direction()
  @typep pagination() :: Collection.direction_limit()
  @typep names_scope() :: {prefix(), prefix()}

  @table Model.AuctionBid
  @table_expiration Model.AuctionExpiration

  @spec fetch!(state(), plain_name(), opts()) :: auction_bid()
  def fetch!(state, plain_name, opts) do
    {:ok, auction_bid} = fetch(state, plain_name, opts)

    auction_bid
  end

  @spec fetch(state(), plain_name(), opts()) :: {:ok, auction_bid()} | :not_found
  def fetch(state, plain_name, opts) do
    case State.get(state, @table, plain_name) do
      {:ok, auction_bid} -> {:ok, render(state, auction_bid, opts)}
      :not_found -> :not_found
    end
  end

  @spec fetch_auctions(state(), pagination(), order_by(), cursor() | nil, boolean()) ::
          {cursor() | nil, [auction_bid()], cursor() | nil}
  def fetch_auctions(state, pagination, :name, cursor, opts) do
    {prev_cursor, auction_bids, next_cursor} =
      Collection.paginate(&Collection.stream(state, @table, &1, nil, cursor), pagination)

    {prev_cursor, Enum.map(auction_bids, &fetch!(state, &1, opts)), next_cursor}
  end

  def fetch_auctions(state, pagination, :expiration, cursor, opts) do
    cursor = deserialize_exp_cursor(cursor)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(
        &Collection.stream(state, @table_expiration, &1, nil, cursor),
        pagination
      )

    auction_bids =
      Enum.map(exp_keys, fn {_exp, plain_name} -> fetch!(state, plain_name, opts) end)

    {serialize_exp_cursor(prev_cursor), auction_bids, serialize_exp_cursor(next_cursor)}
  end

  @spec auctions_stream(state(), prefix(), direction(), names_scope(), cursor()) ::
          Enumerable.t()
  def auctions_stream(state, prefix, direction, scope, cursor) do
    state
    |> Collection.stream(@table, direction, scope, cursor)
    |> Stream.take_while(&String.starts_with?(&1, prefix))
  end

  defp render(
         state,
         Model.auction_bid(
           index: plain_name,
           expire_height: expire_height,
           bids: [last_bid | _rest_bids] = bids
         ),
         _opts
       ) do
    last_bid = Txs.fetch!(state, bi_txi_txi(last_bid))
    name_ttl = Names.expire_after(expire_height)

    %{
      name: plain_name,
      status: "auction",
      active: false,
      info: %{
        auction_end: expire_height,
        last_bid: put_in(last_bid, ["tx", "ttl"], name_ttl),
        bids: Enum.map(bids, &bi_txi_txi/1)
      },
      previous: Names.fetch_previous_list(state, plain_name)
    }
  end

  defp bi_txi_txi({{_height, _mbi}, txi}), do: txi

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
