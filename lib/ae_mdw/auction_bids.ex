defmodule AeMdw.AuctionBids do
  @moduledoc """
  Context module for dealing with AuctionBids.
  """

  alias AeMdw.AuctionBids
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Names
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  @type cursor :: binary() | nil
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type auction_bid() :: map()

  @typep opts() :: Util.opts()
  @typep state() :: State.t()
  @typep order_by :: :expiration | :name
  @typep plain_name() :: Names.plain_name()
  @typep prefix() :: plain_name()
  @typep direction() :: State.direction()
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
      {:ok, auction_bid} ->
        last_micro_time = DbUtil.last_gen_and_time!(state)

        {:ok, render(state, auction_bid, last_micro_time, opts)}

      :not_found ->
        :not_found
    end
  end

  @spec fetch_auction(state(), binary(), opts()) :: {:ok, Names.claim()} | {:error, Error.t()}
  def fetch_auction(state, plain_name, opts) do
    case Name.locate(state, plain_name) do
      {Model.auction_bid(index: plain_name, start_height: _start_height), Model.AuctionBid} ->
        AuctionBids.fetch(state, plain_name, opts)

      {Model.name(), _active_or_inactive} ->
        {:error, ErrInput.NotFound.exception(value: plain_name)}

      nil ->
        {:error, ErrInput.NotFound.exception(value: plain_name)}
    end
  end

  @spec fetch_auctions(state(), pagination(), order_by(), cursor(), opts()) ::
          {:ok, {cursor(), [auction_bid()], cursor()}} | {:error, Error.t()}
  def fetch_auctions(state, pagination, :name, cursor, opts) do
    case DbUtil.last_gen_and_time(state) do
      {:ok, last_micro_time} ->
        streamer = &Collection.stream(state, @table, &1, nil, cursor)

        streamer
        |> Collection.paginate(
          pagination,
          &render(state, &1, last_micro_time, opts),
          & &1
        )
        |> then(&{:ok, &1})

      :no_blocks ->
        {:ok, {nil, [], nil}}
    end
  end

  def fetch_auctions(state, pagination, :expiration, cursor, opts) do
    with {:ok, cursor} <- deserialize_exp_cursor(cursor),
         {:ok, last_micro_time} <- DbUtil.last_gen_and_time(state) do
      streamer = &Collection.stream(state, @table_expiration, &1, nil, cursor)

      streamer
      |> Collection.paginate(
        pagination,
        &render(state, &1, last_micro_time, opts),
        &serialize_exp_cursor/1
      )
      |> then(&{:ok, &1})
    else
      {:error, reason} -> {:error, reason}
      :no_blocks -> {:ok, {nil, [], nil}}
    end
  end

  @spec auctions_stream(state(), prefix(), direction(), names_scope(), cursor()) ::
          Enumerable.t()
  def auctions_stream(state, prefix, direction, scope, cursor) do
    state
    |> Collection.stream(@table, direction, scope, cursor)
    |> Stream.take_while(&String.starts_with?(&1, prefix))
  end

  defp render(state, {_exp, plain_name}, last_micro_time, opts),
    do: render(state, plain_name, last_micro_time, opts)

  defp render(state, plain_name, last_micro_time, opts) do
    render_v3? = Keyword.get(opts, :render_v3?, false)

    if render_v3? do
      render_v3(state, plain_name, last_micro_time, opts)
    else
      render_v2(state, plain_name, last_micro_time, opts)
    end
  end

  defp render_v3(state, plain_name, last_micro_time, opts) when is_binary(plain_name) do
    auction_bid = State.fetch!(state, @table, plain_name)

    render(state, auction_bid, last_micro_time, opts)
  end

  defp render_v3(
         state,
         Model.auction_bid(
           index: plain_name,
           block_index_txi_idx: {block_index, _txi_idx},
           expire_height: expire_height,
           claims_count: claims_count
         ),
         {last_gen, last_micro_time},
         _opts
       ) do
    {last_bid_txi, _last_bid_idx} = last_bid_claim(state, plain_name)

    last_bid =
      state
      |> Txs.fetch!(last_bid_txi)
      |> Map.delete("tx_index")

    name_ttl = Names.expire_after(expire_height)
    protocol = :aec_hard_forks.protocol_effective_at_height(last_gen)

    %{
      name: plain_name,
      activation_time: DbUtil.block_index_to_time(state, block_index),
      auction_end: expire_height,
      approximate_expire_time:
        DbUtil.height_to_time(state, expire_height, last_gen, last_micro_time),
      name_fee: :aec_governance.name_claim_fee(plain_name, protocol),
      last_bid: put_in(last_bid, ["tx", "ttl"], name_ttl),
      claims_count: claims_count
    }
  end

  defp render_v2(state, plain_name, last_micro_time, opts) when is_binary(plain_name) do
    auction_bid = State.fetch!(state, @table, plain_name)

    render_v2(state, auction_bid, last_micro_time, opts)
  end

  defp render_v2(
         state,
         Model.auction_bid(
           index: plain_name,
           block_index_txi_idx: {block_index, _txi_idx},
           start_height: start_height,
           expire_height: expire_height
         ),
         {last_gen, last_micro_time},
         _opts
       ) do
    [{last_bid_txi, _last_bid_idx} | _rest] =
      bids =
      state
      |> Name.stream_nested_resource(Model.AuctionBidClaim, plain_name, start_height)
      |> Enum.to_list()

    last_bid =
      state
      |> Txs.fetch!(last_bid_txi)
      |> Map.delete("tx_index")

    name_ttl = Names.expire_after(expire_height)

    %{
      name: plain_name,
      status: "auction",
      active: false,
      activation_time: DbUtil.block_index_to_time(state, block_index),
      info: %{
        auction_end: expire_height,
        approximate_expire_time:
          DbUtil.height_to_time(state, expire_height, last_gen, last_micro_time),
        last_bid: put_in(last_bid, ["tx", "ttl"], name_ttl),
        bids: Enum.map(bids, &txi_idx_txi/1)
      },
      previous: Names.fetch_previous_list(state, plain_name)
    }
  end

  defp txi_idx_txi({txi, _idx}), do: txi

  defp serialize_exp_cursor({exp_height, name}),
    do: "#{exp_height}-#{Base.encode64(name, padding: false)}"

  defp deserialize_exp_cursor(nil), do: {:ok, nil}

  defp deserialize_exp_cursor(cursor_bin) do
    with [_match0, exp_height, name] <- Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin),
         {:ok, decoded_name} <- Base.decode64(name, padding: false) do
      {:ok, {String.to_integer(exp_height), decoded_name}}
    else
      _invalid_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp last_bid_claim(state, plain_name) do
    state
    |> Name.stream_nested_resource(Model.AuctionBidClaim, plain_name)
    |> Enum.at(0)
  end
end
