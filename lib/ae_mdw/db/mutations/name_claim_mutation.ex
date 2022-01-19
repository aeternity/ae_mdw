defmodule AeMdw.Db.NameClaimMutation do
  @moduledoc """
  Processes name_claim_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name, as: DBName
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Ets
  alias AeMdw.Log
  alias AeMdw.Names
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  require Logger
  require Model

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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        plain_name: plain_name,
        name_hash: name_hash,
        owner_pk: owner_pk,
        name_fee: name_fee,
        is_lima?: is_lima?,
        txi: txi,
        block_index: {height, _mbi} = block_index,
        timeout: timeout
      }) do
    m_owner = Model.owner(index: {owner_pk, plain_name})
    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)

    DBName.cache_through_write(Model.PlainName, m_plain_name)

    case timeout do
      0 ->
        previous = Util.ok_nil(DBName.cache_through_read(Model.InactiveName, plain_name))
        expire = DBName.expire_after(height)

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

        DBName.cache_through_write(Model.ActiveName, m_name)
        DBName.cache_through_write(Model.ActiveNameOwner, m_owner)
        DBName.cache_through_write(Model.ActiveNameExpiration, m_name_exp)
        DBName.cache_through_delete_inactive(previous)

        lock_amount = (is_lima? && name_fee) || :aec_governance.name_claim_locked_fee()
        IntTransfer.fee({height, txi}, :lock_name, owner_pk, txi, lock_amount)
        Ets.inc(:stat_sync_cache, :active_names)
        previous && Ets.dec(:stat_sync_cache, :inactive_names)

        log_name_change(height, plain_name, "activate")

      timeout ->
        auction_end = height + timeout
        m_auction_exp = Model.expiration(index: {auction_end, plain_name})

        make_m_bid =
          &Model.auction_bid(index: {plain_name, {block_index, txi}, auction_end, owner_pk, &1})

        IntTransfer.fee({height, txi}, :spend_name, owner_pk, txi, name_fee)

        m_bid =
          case DBName.cache_through_prev(Model.AuctionBid, DBName.bid_top_key(plain_name)) do
            :not_found ->
              make_m_bid.([{block_index, txi}])

            {:ok,
             {^plain_name, {_, prev_txi}, prev_auction_end, prev_owner, prev_bids} = prev_key} ->
              DBName.cache_through_delete(Model.AuctionBid, prev_key)
              DBName.cache_through_delete(Model.AuctionOwner, {prev_owner, plain_name})
              DBName.cache_through_delete(Model.AuctionExpiration, {prev_auction_end, plain_name})

              log_auction_change(
                height,
                plain_name,
                "delete auction ending in #{prev_auction_end}"
              )

              %{tx: prev_tx} = read_cached_raw_tx!(prev_txi)

              IntTransfer.fee(
                {height, txi},
                :refund_name,
                prev_owner,
                prev_txi,
                prev_tx.name_fee
              )

              make_m_bid.([{block_index, txi} | prev_bids])
          end

        DBName.cache_through_write(Model.AuctionBid, m_bid)
        DBName.cache_through_write(Model.AuctionOwner, m_owner)
        DBName.cache_through_write(Model.AuctionExpiration, m_auction_exp)
        Ets.inc(:stat_sync_cache, :active_auctions)

        log_auction_change(height, plain_name, "activate auction expiring in #{auction_end}")
    end
  end

  defp log_auction_change(height, plain_name, change),
    do: Log.info("[#{height}][auction] #{change} #{plain_name}")

  defp log_name_change(height, plain_name, change),
    do: Log.info("[#{height}][name] #{change} #{plain_name}")

  defp read_raw_tx!(txi),
    do: Format.to_raw_map(DbUtil.read_tx!(txi))

  defp read_cached_raw_tx!(txi) do
    case :ets.lookup(:tx_sync_cache, txi) do
      [{^txi, m_tx}] -> Format.to_raw_map(m_tx)
      [] -> read_raw_tx!(txi)
    end
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.NameClaimMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
