defmodule AeMdw.Db.NameClaimMutation do
  @moduledoc """
  Processes name_claim_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.Sync.ObjectKeys
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Names
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Logger
  require Model

  @derive AeMdw.Db.Mutation
  defstruct [
    :plain_name,
    :name_hash,
    :owner_pk,
    :name_fee,
    :lima_or_higher?,
    :txi_idx,
    :block_index,
    :protocol_version
  ]

  @opaque t() :: %__MODULE__{
            plain_name: Names.plain_name(),
            name_hash: Names.name_hash(),
            owner_pk: Db.pubkey(),
            name_fee: Names.name_fee(),
            lima_or_higher?: boolean(),
            txi_idx: Txs.txi_idx(),
            block_index: Blocks.block_index(),
            protocol_version: Db.protocol_version()
          }

  @spec new(
          Names.plain_name(),
          Names.name_hash(),
          Db.pubkey(),
          Names.name_fee(),
          boolean(),
          Txs.txi_idx(),
          Blocks.block_index(),
          Db.protocol_version()
        ) :: t()
  def new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        lima_or_higher?,
        txi_idx,
        block_index,
        protocol_version
      ) do
    %__MODULE__{
      plain_name: plain_name,
      name_hash: name_hash,
      owner_pk: owner_pk,
      name_fee: name_fee,
      lima_or_higher?: lima_or_higher?,
      txi_idx: txi_idx,
      block_index: block_index,
      protocol_version: protocol_version
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          plain_name: plain_name,
          name_hash: name_hash,
          owner_pk: owner_pk,
          name_fee: name_fee,
          lima_or_higher?: lima_or_higher?,
          txi_idx: txi_idx,
          block_index: {height, _mbi} = block_index,
          protocol_version: protocol_version
        },
        state
      ) do
    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)

    state2 = State.put(state, Model.PlainName, m_plain_name)

    timeout = :aec_governance.name_claim_bid_timeout(plain_name, protocol_version)

    if timeout == 0 do
      expire = Names.expire_after(height)

      m_name =
        Model.name(
          index: plain_name,
          active: height,
          expire: expire,
          owner: owner_pk,
          auction_timeout: 0
        )

      lock_amount = (lima_or_higher? && name_fee) || :aec_governance.name_claim_locked_fee()

      name_claim = Model.name_claim(index: {plain_name, height, txi_idx})

      ObjectKeys.put_active_name(state, plain_name)

      state2
      |> Name.put_active(m_name)
      |> State.put(Model.NameClaim, name_claim)
      |> Name.delete_inactive(plain_name)
      |> IntTransfer.fee({height, txi_idx}, :lock_name, owner_pk, txi_idx, lock_amount)
      |> State.inc_stat(:burned_in_auctions, lock_amount)
      |> Names.increment_names_count(owner_pk)
    else
      state3 =
        IntTransfer.fee(state2, {height, txi_idx}, :spend_name, owner_pk, txi_idx, name_fee)

      state4 =
        case State.get(state3, Model.AuctionBid, plain_name) do
          :not_found ->
            auction_claim = Model.auction_bid_claim(index: {plain_name, height, txi_idx})
            auction_end = height + timeout

            m_auction_bid =
              Model.auction_bid(
                index: plain_name,
                start_height: height,
                block_index_txi_idx: {block_index, txi_idx},
                expire_height: auction_end,
                owner: owner_pk
              )

            m_auction_exp = Model.expiration(index: {auction_end, plain_name})

            state3
            |> State.inc_stat(:auctions_started)
            |> State.put(Model.AuctionBidClaim, auction_claim)
            |> State.put(Model.AuctionBid, m_auction_bid)
            |> State.put(Model.AuctionExpiration, m_auction_exp)

          {:ok,
           Model.auction_bid(
             start_height: start_height,
             block_index_txi_idx: {_bi, prev_txi_idx},
             expire_height: prev_auction_end,
             owner: prev_owner
           ) = auction_bid} ->
            auction_end =
              prev_auction_end +
                :aec_governance.name_claim_bid_extension(plain_name, protocol_version)

            prev_name_claim_tx = DbUtil.read_node_tx(state, prev_txi_idx)
            prev_name_fee = :aens_claim_tx.name_fee(prev_name_claim_tx)
            auction_claim = Model.auction_bid_claim(index: {plain_name, start_height, txi_idx})

            m_auction_bid =
              Model.auction_bid(auction_bid,
                block_index_txi_idx: {block_index, txi_idx},
                expire_height: auction_end,
                owner: owner_pk
              )

            state3
            |> State.delete(Model.AuctionBid, plain_name)
            |> State.delete(Model.AuctionOwner, {prev_owner, plain_name})
            |> State.delete(
              Model.AuctionExpiration,
              {prev_auction_end, plain_name}
            )
            |> IntTransfer.fee(
              {height, txi_idx},
              :refund_name,
              prev_owner,
              prev_txi_idx,
              prev_name_fee
            )
            |> State.inc_stat(:locked_in_auctions, name_fee - prev_name_fee)
            |> State.put(Model.AuctionBidClaim, auction_claim)
            |> State.put(Model.AuctionBid, m_auction_bid)
            |> State.put(
              Model.AuctionExpiration,
              Model.expiration(index: {auction_end, plain_name})
            )
        end

      state4
      |> State.put(Model.AuctionOwner, Model.owner(index: {owner_pk, plain_name}))
    end
  end
end
