defmodule AeMdw.Migrations.IndexAuctionsClaimsCount do
  @moduledoc """
  Index auctions claims count based on NameClaim records.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  import Record, only: [defrecord: 2]

  require Model

  defrecord :auction_bid,
    index: nil,
    start_height: nil,
    block_index_txi_idx: nil,
    expire_height: nil,
    owner: nil

  defrecord :name,
    index: nil,
    active: nil,
    expire: nil,
    revoke: nil,
    auction_timeout: 0,
    owner: nil

  @dialyzer {:nowarn_function, run: 2}

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    auctions_mutations =
      state
      |> Collection.stream(Model.AuctionBid, nil)
      |> Stream.map(fn plain_name ->
        auction_bid(
          start_height: start_height,
          block_index_txi_idx: block_index_txi_idx,
          expire_height: expire_height,
          owner: owner
        ) = State.fetch!(state, Model.AuctionBid, plain_name)

        claims_count =
          state
          |> Collection.stream(Model.AuctionBidClaim, {plain_name, -1, -1})
          |> Stream.take_while(&match?({^plain_name, _height, _txi_idx}, &1))
          |> Enum.count()

        new_auction =
          Model.auction_bid(
            index: plain_name,
            start_height: start_height,
            block_index_txi_idx: block_index_txi_idx,
            expire_height: expire_height,
            owner: owner,
            claims_count: claims_count
          )

        WriteMutation.new(Model.AuctionBid, new_auction)
      end)

    [
      Model.ActiveName,
      Model.InactiveName
    ]
    |> Enum.map(fn source ->
      state
      |> Collection.stream(source, nil)
      |> Stream.map(&{State.fetch!(state, source, &1), source})
    end)
    |> Collection.merge(:forward)
    |> Stream.transform(<<>>, fn {name, source}, first_char_acc ->
      name(
        index: plain_name,
        active: active,
        expire: expire,
        revoke: revoke,
        auction_timeout: auction_timeout,
        owner: owner
      ) = name

      first_char = String.at(plain_name, 0)

      if first_char != first_char_acc do
        IO.puts("Processing names that begin with `#{first_char}`..")
      end

      claims_count =
        state
        |> Collection.stream(Model.NameClaim, {plain_name, active, -1})
        |> Stream.take_while(&match?({^plain_name, ^active, _txi_idx}, &1))
        |> Enum.count()

      new_name =
        Model.name(
          index: plain_name,
          active: active,
          expire: expire,
          revoke: revoke,
          auction_timeout: auction_timeout,
          owner: owner,
          claims_count: claims_count
        )

      {[WriteMutation.new(source, new_name)], first_char}
    end)
    |> Stream.concat(auctions_mutations)
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end
