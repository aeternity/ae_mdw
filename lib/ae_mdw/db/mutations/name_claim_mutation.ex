defmodule AeMdw.Db.NameClaimMutation do
  @moduledoc """
  Processes name_claim_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Ets
  alias AeMdw.Names
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  require Logger
  require Model

  import AeMdw.Db.Name,
    only: [
      cache_through_read: 3,
      cache_through_write: 3,
      cache_through_delete: 3,
      cache_through_delete_inactive: 2,
      cache_through_prev: 2,
      bid_top_key: 1,
      expire_after: 1
    ]

  @derive AeMdw.Db.TxnMutation
  defstruct [
    :plain_name,
    :name_hash,
    :owner_pk,
    :name_fee,
    :is_lima?,
    :txi,
    :block_index,
    :timeout
  ]

  @opaque t() :: %__MODULE__{
            plain_name: Names.plain_name(),
            name_hash: Names.name_hash(),
            owner_pk: Db.pubkey(),
            name_fee: Names.name_fee(),
            is_lima?: boolean(),
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
  def new(plain_name, name_hash, owner_pk, name_fee, is_lima?, txi, block_index, timeout) do
    %__MODULE__{
      plain_name: plain_name,
      name_hash: name_hash,
      owner_pk: owner_pk,
      name_fee: name_fee,
      is_lima?: is_lima?,
      txi: txi,
      block_index: block_index,
      timeout: timeout
    }
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          plain_name: plain_name,
          name_hash: name_hash,
          owner_pk: owner_pk,
          name_fee: name_fee,
          is_lima?: is_lima?,
          txi: txi,
          block_index: {height, _mbi} = block_index,
          timeout: timeout
        },
        txn
      ) do
    m_owner = Model.owner(index: {owner_pk, plain_name})
    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)

    cache_through_write(txn, Model.PlainName, m_plain_name)

    case timeout do
      0 ->
        previous = Util.ok_nil(cache_through_read(txn, Model.InactiveName, plain_name))
        expire = expire_after(height)

        m_name =
          Model.name(
            index: plain_name,
            active: height,
            expire: expire,
            claims: [{block_index, txi}],
            owner: owner_pk,
            previous: previous
          )

        m_name_exp = Model.expiration(index: {expire, plain_name})

        cache_through_write(txn, Model.ActiveName, m_name)
        cache_through_write(txn, Model.ActiveNameOwner, m_owner)
        cache_through_write(txn, Model.ActiveNameExpiration, m_name_exp)
        cache_through_delete_inactive(txn, previous)

        lock_amount = (is_lima? && name_fee) || :aec_governance.name_claim_locked_fee()
        IntTransfer.fee(txn, {height, txi}, :lock_name, owner_pk, txi, lock_amount)
        Ets.inc(:stat_sync_cache, :names_activated)

      timeout ->
        auction_end = height + timeout
        m_auction_exp = Model.expiration(index: {auction_end, plain_name})

        make_m_bid =
          &Model.auction_bid(index: {plain_name, {block_index, txi}, auction_end, owner_pk, &1})

        IntTransfer.fee(txn, {height, txi}, :spend_name, owner_pk, txi, name_fee)

        m_bid =
          case cache_through_prev(Model.AuctionBid, bid_top_key(plain_name)) do
            :not_found ->
              make_m_bid.([{block_index, txi}])

            {:ok,
             {^plain_name, {_, prev_txi}, prev_auction_end, prev_owner, prev_bids} = prev_key} ->
              cache_through_delete(txn, Model.AuctionBid, prev_key)
              cache_through_delete(txn, Model.AuctionOwner, {prev_owner, plain_name})

              cache_through_delete(
                txn,
                Model.AuctionExpiration,
                {prev_auction_end, plain_name}
              )

              %{tx: prev_tx} = read_cached_raw_tx!(prev_txi)

              IntTransfer.fee(
                txn,
                {height, txi},
                :refund_name,
                prev_owner,
                prev_txi,
                prev_tx.name_fee
              )

              make_m_bid.([{block_index, txi} | prev_bids])
          end

        cache_through_write(txn, Model.AuctionBid, m_bid)
        cache_through_write(txn, Model.AuctionOwner, m_owner)
        cache_through_write(txn, Model.AuctionExpiration, m_auction_exp)

        Ets.inc(:stat_sync_cache, :auctions_started)
    end
  end

  defp read_raw_tx!(txi),
    do: Format.to_raw_map(DbUtil.read_tx!(txi))

  defp read_cached_raw_tx!(txi) do
    case :ets.lookup(:tx_sync_cache, txi) do
      [{^txi, m_tx}] -> Format.to_raw_map(m_tx)
      [] -> read_raw_tx!(txi)
    end
  end
end
