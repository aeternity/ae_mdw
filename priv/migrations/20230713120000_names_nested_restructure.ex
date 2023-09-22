defmodule AeMdw.Migrations.NamesNestedRestructure.OldName do
  @moduledoc false

  require Record

  Record.defrecord(:name,
    index: nil,
    active: nil,
    expire: nil,
    revoke: nil,
    auction_timeout: nil,
    owner: nil,
    previous: nil
  )
end

defmodule AeMdw.Migrations.NamesNestedRestructure do
  @moduledoc """
  Re-indexes names and auctions nested references into separate tables.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias __MODULE__.OldName

  require Model
  require Record
  require OldName

  Record.defrecord(:auction_bid,
    index: nil,
    block_index_txi_idx: nil,
    expire_height: nil,
    owner: nil,
    bids: nil
  )

  Record.defrecord(:name,
    index: nil,
    active: nil,
    expire: nil,
    claims: nil,
    updates: nil,
    transfers: nil,
    revoke: nil,
    auction_timeout: nil,
    owner: nil,
    previous: nil
  )

  @chunk_size 1_000

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count =
      [Model.ActiveName, Model.InactiveName, Model.AuctionBid]
      |> Enum.map(fn table ->
        state
        |> Collection.stream(table, nil)
        |> Stream.map(&{&1, table})
      end)
      |> Collection.merge(:forward)
      |> Stream.transform("", fn {plain_name, source}, prev_char ->
        first_char = String.at(plain_name, 0)

        if first_char != prev_char do
          IO.puts("Processing names and auctions starting with #{first_char}..")
        end

        {[{plain_name, source}], first_char}
      end)
      |> Stream.map(fn {plain_name, source} ->
        {State.fetch!(state, source, plain_name), source}
      end)
      |> Stream.map(fn {old_record, source} ->
        with {:ok, new_record, nested_mutations} <- restructure_record(old_record, source) do
          {:ok, [WriteMutation.new(source, new_record) | nested_mutations]}
        end
      end)
      |> Stream.filter(&match?({:ok, _mutations}, &1))
      |> Stream.chunk_every(@chunk_size)
      |> Stream.map(fn ok_mutations ->
        mutations = Enum.flat_map(ok_mutations, fn {:ok, mutations} -> mutations end)

        _new_state = State.commit(state, mutations)

        length(ok_mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end

  defp restructure_record(nil, _source), do: {:ok, nil, []}

  defp restructure_record(auction_bid() = auction_bid, Model.AuctionBid) do
    auction_bid(
      index: plain_name,
      block_index_txi_idx: block_index_txi_idx,
      expire_height: expire_height,
      owner: owner,
      bids: bids
    ) = auction_bid

    new_record =
      Model.auction_bid(
        index: plain_name,
        block_index_txi_idx: block_index_txi_idx,
        expire_height: expire_height,
        owner: owner
      )

    nested_mutations =
      Enum.map(bids, fn {_bi, bid_txi_idx} ->
        WriteMutation.new(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, bid_txi_idx})
        )
      end)

    {:ok, new_record, nested_mutations}
  end

  defp restructure_record(name() = name, source) do
    name(
      index: plain_name,
      active: active,
      expire: expire,
      claims: claims,
      updates: updates,
      transfers: transfers,
      revoke: revoke,
      auction_timeout: auction_timeout,
      owner: owner,
      previous: previous
    ) = name

    claims_mutations =
      Enum.map(claims, fn {_bi, txi_idx} ->
        WriteMutation.new(Model.NameClaim, Model.name_claim(index: {plain_name, active, txi_idx}))
      end)

    updates_mutations =
      Enum.map(updates, fn {_bi, txi_idx} ->
        WriteMutation.new(
          Model.NameUpdate,
          Model.name_update(index: {plain_name, active, txi_idx})
        )
      end)

    transfers_mutations =
      Enum.map(transfers, fn {_bi, txi_idx} ->
        WriteMutation.new(
          Model.NameTransfer,
          Model.name_transfer(index: {plain_name, active, txi_idx})
        )
      end)

    nested_mutations = claims_mutations ++ updates_mutations ++ transfers_mutations
    {:ok, new_previous, previous_mutations} = restructure_record(previous, source)

    new_record =
      OldName.name(
        index: plain_name,
        active: active,
        expire: expire,
        revoke: revoke,
        auction_timeout: auction_timeout,
        owner: owner,
        previous: new_previous
      )

    {:ok, new_record, previous_mutations ++ nested_mutations}
  end

  defp restructure_record(_record, _source), do: :already_restructured
end
