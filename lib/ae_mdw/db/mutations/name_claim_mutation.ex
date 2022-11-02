defmodule AeMdw.Db.NameClaimMutation do
  @moduledoc """
  Processes name_claim_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Names
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  require Logger
  require Model

  @derive AeMdw.Db.Mutation
  defstruct [
    :plain_name,
    :name_hash,
    :owner_pk,
    :name_fee,
    :lima_or_higher?,
    :txi,
    :block_index,
    :timeout
  ]

  @opaque t() :: %__MODULE__{
            plain_name: Names.plain_name(),
            name_hash: Names.name_hash(),
            owner_pk: Db.pubkey(),
            name_fee: Names.name_fee(),
            lima_or_higher?: boolean(),
            txi: Txs.txi(),
            block_index: Blocks.block_index(),
            timeout: Names.auction_timeout()
          }

  @spec new(
          Names.plain_name(),
          Names.name_hash(),
          Db.pubkey(),
          Names.name_fee(),
          boolean(),
          Txs.txi(),
          Blocks.block_index(),
          Names.auction_timeout()
        ) :: t()
  def new(plain_name, name_hash, owner_pk, name_fee, lima_or_higher?, txi, block_index, timeout) do
    %__MODULE__{
      plain_name: plain_name,
      name_hash: name_hash,
      owner_pk: owner_pk,
      name_fee: name_fee,
      lima_or_higher?: lima_or_higher?,
      txi: txi,
      block_index: block_index,
      timeout: timeout
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
          txi: txi,
          block_index: {height, _mbi} = block_index,
          timeout: timeout
        },
        state
      ) do
    m_owner = Model.owner(index: {owner_pk, plain_name})
    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)

    state2 = Name.cache_through_write(state, Model.PlainName, m_plain_name)

    case timeout do
      0 ->
        previous = Util.ok_nil(Name.cache_through_read(state, Model.InactiveName, plain_name))
        expire = Names.expire_after(height)

        m_name =
          Model.name(
            index: plain_name,
            active: height,
            expire: expire,
            claims: [{block_index, txi}],
            owner: owner_pk,
            previous: previous,
            auction_timeout: 0
          )

        m_name_activation = Model.activation(index: {height, plain_name})
        m_name_exp = Model.expiration(index: {expire, plain_name})
        lock_amount = (lima_or_higher? && name_fee) || :aec_governance.name_claim_locked_fee()

        m_name_owner_deactivation =
          Model.owner_deactivation(index: {owner_pk, expire, plain_name})

        state2
        |> Name.cache_through_write(Model.ActiveName, m_name)
        |> Name.cache_through_write(Model.ActiveNameOwner, m_owner)
        |> Name.cache_through_write(Model.ActiveNameActivation, m_name_activation)
        |> Name.cache_through_write(Model.ActiveNameExpiration, m_name_exp)
        |> State.put(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
        |> Name.cache_through_delete_inactive(previous)
        |> IntTransfer.fee({height, txi}, :lock_name, owner_pk, txi, lock_amount)
        |> State.inc_stat(:names_activated)
        |> State.inc_stat(:burned_in_auctions, lock_amount)

      timeout ->
        auction_end = height + timeout
        m_auction_exp = Model.expiration(index: {auction_end, plain_name})

        make_m_bid =
          &Model.auction_bid(
            index: plain_name,
            block_index_txi: {block_index, txi},
            expire_height: auction_end,
            owner: owner_pk,
            bids: &1
          )

        state3 = IntTransfer.fee(state2, {height, txi}, :spend_name, owner_pk, txi, name_fee)

        {m_bid, state4} =
          case Name.cache_through_read(state, Model.AuctionBid, plain_name) do
            nil ->
              state4 = State.inc_stat(state3, :auctions_started)
              {make_m_bid.([{block_index, txi}]), state4}

            {:ok,
             Model.auction_bid(
               block_index_txi: {_bi, prev_txi},
               expire_height: prev_auction_end,
               owner: prev_owner,
               bids: prev_bids
             )} ->
              %{tx: %{name_fee: prev_name_fee}} = read_cached_raw_tx!(state, prev_txi)

              state4 =
                state3
                |> Name.cache_through_delete(Model.AuctionBid, plain_name)
                |> Name.cache_through_delete(Model.AuctionOwner, {prev_owner, plain_name})
                |> Name.cache_through_delete(
                  Model.AuctionExpiration,
                  {prev_auction_end, plain_name}
                )
                |> IntTransfer.fee(
                  {height, txi},
                  :refund_name,
                  prev_owner,
                  prev_txi,
                  prev_name_fee
                )
                |> State.inc_stat(:locked_in_auctions, name_fee - prev_name_fee)

              {make_m_bid.([{block_index, txi} | prev_bids]), state4}
          end

        state4
        |> Name.cache_through_write(Model.AuctionBid, m_bid)
        |> Name.cache_through_write(Model.AuctionOwner, m_owner)
        |> Name.cache_through_write(Model.AuctionExpiration, m_auction_exp)
    end
  end

  defp read_raw_tx!(state, txi),
    do: Format.to_raw_map(state, DbUtil.read_tx!(state, txi))

  defp read_cached_raw_tx!(state, txi) do
    case :ets.lookup(:tx_sync_cache, txi) do
      [{^txi, m_tx}] -> Format.to_raw_map(state, m_tx)
      [] -> read_raw_tx!(state, txi)
    end
  end
end
