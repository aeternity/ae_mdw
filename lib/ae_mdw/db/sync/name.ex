defmodule AeMdw.Db.Sync.Name do
  # credo:disable-for-this-file
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Sync
  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate

  require Record
  require Model
  require Ex2ms

  import AeMdw.Db.Name,
    only: [
      cache_through_read!: 2,
      cache_through_read: 2,
      cache_through_prev: 2,
      cache_through_write: 2,
      cache_through_delete: 2,
      cache_through_delete_inactive: 1,
      revoke_or_expire_height: 1,
      revoke_or_expire_height: 2
    ]

  import AeMdw.Db.Util
  import AeMdw.Ets
  import AeMdw.Util

  ##########

  def claim(plain_name, name_hash, tx, txi, {height, _} = bi) do
    account_pk = Validate.id!(:aens_claim_tx.account_id(tx))
    name_fee = :aens_claim_tx.name_fee(tx)
    m_owner = Model.owner(index: {account_pk, plain_name})

    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)
    cache_through_write(Model.PlainName, m_plain_name)

    proto_vsn = proto_vsn(height)
    is_lima? = proto_vsn >= AE.lima_vsn()

    case :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn) do
      0 ->
        previous = ok_nil(cache_through_read(Model.InactiveName, plain_name))
        expire = Name.expire_after(height)

        m_name =
          Model.name(
            index: plain_name,
            active: height,
            expire: expire,
            claims: [{bi, txi}],
            owner: account_pk,
            previous: previous
          )

        m_name_exp = Model.expiration(index: {expire, plain_name})

        cache_through_write(Model.ActiveName, m_name)
        cache_through_write(Model.ActiveNameOwner, m_owner)
        cache_through_write(Model.ActiveNameExpiration, m_name_exp)
        cache_through_delete_inactive(previous)

        lock_amount = (is_lima? && name_fee) || :aec_governance.name_claim_locked_fee()
        Sync.IntTransfer.fee({height, txi}, :lock_name, account_pk, txi, lock_amount)
        inc(:stat_sync_cache, :active_names)
        previous && dec(:stat_sync_cache, :inactive_names)

      timeout ->
        auction_end = height + timeout
        m_auction_exp = Model.expiration(index: {auction_end, plain_name})

        make_m_bid =
          &Model.auction_bid(index: {plain_name, {bi, txi}, auction_end, account_pk, &1})

        Sync.IntTransfer.fee({height, txi}, :spend_name, account_pk, txi, name_fee)

        m_bid =
          case cache_through_prev(Model.AuctionBid, Name.bid_top_key(plain_name)) do
            :not_found ->
              make_m_bid.([{bi, txi}])

            {:ok,
             {^plain_name, {_, prev_txi}, prev_auction_end, prev_owner, prev_bids} = prev_key} ->
              cache_through_delete(Model.AuctionBid, prev_key)
              cache_through_delete(Model.AuctionOwner, {prev_owner, plain_name})
              cache_through_delete(Model.AuctionExpiration, {prev_auction_end, plain_name})

              %{tx: prev_tx} = read_cached_raw_tx!(prev_txi)

              Sync.IntTransfer.fee(
                {height, txi},
                :refund_name,
                prev_owner,
                prev_txi,
                prev_tx.name_fee
              )

              make_m_bid.([{bi, txi} | prev_bids])
          end

        cache_through_write(Model.AuctionBid, m_bid)
        cache_through_write(Model.AuctionOwner, m_owner)
        cache_through_write(Model.AuctionExpiration, m_auction_exp)
        inc(:stat_sync_cache, :active_auctions)
    end
  end

  def update(name_hash, tx, txi, {height, _} = bi) do
    delta_ttl = tx_val(tx, :name_update_tx, :name_ttl)
    pointers = tx_val(tx, :name_update_tx, :pointers)
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(Model.ActiveName, plain_name)
    old_expire = Model.name(m_name, :expire)
    new_expire = height + delta_ttl
    updates = [{bi, txi} | Model.name(m_name, :updates)]
    m_name_exp = Model.expiration(index: {new_expire, plain_name})
    m_name = Model.name(m_name, expire: new_expire, updates: updates)

    cache_through_delete(Model.ActiveNameExpiration, {old_expire, plain_name})

    for ptr <- pointers do
      m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi}))
      cache_through_write(Model.Pointee, m_pointee)
    end

    cond do
      delta_ttl > 0 ->
        cache_through_write(Model.ActiveNameExpiration, m_name_exp)
        cache_through_write(Model.ActiveName, m_name)

      delta_ttl == 0 ->
        owner = Model.name(m_name, :owner)
        cache_through_delete(Model.ActiveName, plain_name)
        cache_through_delete(Model.ActiveNameOwner, {owner, plain_name})
        cache_through_write(Model.InactiveName, m_name)
        cache_through_write(Model.InactiveNameExpiration, m_name_exp)
        log_expired_name(height, plain_name)
    end
  end

  def transfer(name_hash, tx, txi, {_height, _} = bi) do
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(Model.ActiveName, plain_name)
    old_owner = Model.name(m_name, :owner)
    new_owner = :aens_transfer_tx.recipient_pubkey(tx)

    transfers = [{bi, txi} | Model.name(m_name, :transfers)]
    m_name = Model.name(m_name, transfers: transfers, owner: new_owner)
    m_owner = Model.owner(index: {new_owner, plain_name})

    cache_through_delete(Model.ActiveNameOwner, {old_owner, plain_name})
    cache_through_write(Model.ActiveNameOwner, m_owner)
    cache_through_write(Model.ActiveName, m_name)
  end

  def revoke(name_hash, _tx, txi, {height, _} = bi) do
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(Model.ActiveName, plain_name)
    expire = Model.name(m_name, :expire)
    owner = Model.name(m_name, :owner)
    cache_through_delete(Model.ActiveNameExpiration, {expire, plain_name})
    cache_through_delete(Model.ActiveNameOwner, {owner, plain_name})
    cache_through_delete(Model.ActiveName, plain_name)

    m_name = Model.name(m_name, revoke: {bi, txi})
    m_exp = Model.expiration(index: {height, plain_name})
    cache_through_write(Model.InactiveName, m_name)
    cache_through_write(Model.InactiveNameExpiration, m_exp)
    inc(:stat_sync_cache, :inactive_names)
    dec(:stat_sync_cache, :active_names)
  end

  ##########

  def expire(height) do
    name_mspec =
      Ex2ms.fun do
        {:expiration, {^height, name}, :_} -> name
      end

    :mnesia.select(Model.ActiveNameExpiration, name_mspec)
    |> Enum.each(&expire_name(height, &1))

    auction_mspec =
      Ex2ms.fun do
        {:expiration, {^height, name}, tm} -> {name, tm}
      end

    :mnesia.select(Model.AuctionExpiration, auction_mspec)
    |> Enum.each(fn {name, timeout} -> expire_auction(height, name, timeout) end)
  end

  def expire_name(height, plain_name) do
    m_name = cache_through_read!(Model.ActiveName, plain_name)
    m_exp = Model.expiration(index: {height, plain_name})

    if Model.name(m_name, :expire) == height do
      owner = Model.name(m_name, :owner)
      cache_through_write(Model.InactiveName, m_name)
      cache_through_write(Model.InactiveNameExpiration, m_exp)
      cache_through_delete(Model.ActiveName, plain_name)
      cache_through_delete(Model.ActiveNameOwner, {owner, plain_name})
      cache_through_delete(Model.ActiveNameExpiration, {height, plain_name})
      inc(:stat_sync_cache, :inactive_names)
      dec(:stat_sync_cache, :active_names)
      log_expired_name(height, plain_name)
    else
      cache_through_delete(Model.ActiveNameExpiration, {height, plain_name})
      Log.info("[#{height}] deleted old expiration for name #{plain_name}")
    end
  end

  def expire_auction(height, plain_name, timeout) do
    {_, {_, txi}, _, owner, bids} =
      bid_key = ok!(cache_through_prev(Model.AuctionBid, Name.bid_top_key(plain_name)))

    previous = ok_nil(cache_through_read(Model.InactiveName, plain_name))
    expire = Name.expire_after(height)

    m_name =
      Model.name(
        index: plain_name,
        active: height,
        expire: expire,
        claims: bids,
        auction_timeout: timeout,
        owner: owner,
        previous: previous
      )

    m_name_exp = Model.expiration(index: {expire, plain_name})
    m_owner = Model.owner(index: {owner, plain_name})

    ensure_no_exsiting_active_name_expiration(plain_name)
    cache_through_write(Model.ActiveName, m_name)
    cache_through_write(Model.ActiveNameOwner, m_owner)
    cache_through_write(Model.ActiveNameExpiration, m_name_exp)
    cache_through_delete(Model.AuctionExpiration, {height, plain_name})
    cache_through_delete(Model.AuctionOwner, {owner, plain_name})
    cache_through_delete(Model.AuctionBid, bid_key)
    cache_through_delete_inactive(previous)

    %{tx: winning_tx} = read_raw_tx!(txi)
    Sync.IntTransfer.fee({height, -1}, :lock_name, owner, txi, winning_tx.name_fee)
    inc(:stat_sync_cache, :active_names)
    dec(:stat_sync_cache, :active_auctions)
    log_expired_auction(height, plain_name)
  end

  def ensure_no_exsiting_active_name_expiration(plain_name) do
    name_mspec =
      Ex2ms.fun do
        {:expiration, {height, ^plain_name}, :_} -> {height, ^plain_name}
      end

    expirations = :mnesia.select(Model.ActiveNameExpiration, name_mspec)

    if Enum.count(expirations) > 0 do
      Log.info("Removing exsiting active name expirations #{inspect(expirations)}")

      expirations
      |> Enum.map(fn key -> cache_through_delete(Model.ActiveNameExpiration, key) end)
    end
  end

  ##########

  def plain_name!(name_hash),
    do: cache_through_read!(Model.PlainName, name_hash) |> Model.plain_name(:value)

  def log_expired_name(height, plain_name),
    do: Log.info("[#{height}] expiring name #{plain_name}")

  def log_expired_auction(height, plain_name),
    do: Log.info("[#{height}] expiring auction for #{plain_name}")

  ################################################################################
  #
  #
  #

  def invalidate(new_height) do
    inactives = expirations(Model.InactiveNameExpiration, new_height)
    actives = expirations(Model.ActiveNameExpiration, new_height)
    auctions = expirations(Model.AuctionExpiration, new_height)

    plain_names = Enum.reduce([actives, auctions], inactives, &MapSet.union/2)

    {all_dels_nested, all_writes_nested} =
      Enum.reduce(plain_names, {%{}, %{}}, fn plain_name, {all_dels, all_writes} ->
        inactive = ok_nil(cache_through_read(Model.InactiveName, plain_name))
        active = ok_nil(cache_through_read(Model.ActiveName, plain_name))
        auction = Name.locate_bid(plain_name)

        {dels, writes} = invalidate(plain_name, inactive, active, auction, new_height)

        {merge_maps([all_dels, dels], &cons_merger/3),
         merge_maps([all_writes, writes], &cons_merger/3)}
      end)

    {flatten_map_values(all_dels_nested), flatten_map_values(all_writes_nested)}
  end

  def expirations(table, new_height) do
    collect_keys(table, MapSet.new(), {new_height, ""}, &next/2, fn
      {height, name}, acc when height >= new_height ->
        {:cont, MapSet.put(acc, name)}

      {_prev_height, _name}, acc ->
        {:halt, acc}
    end)
  end

  def invalidate(_plain_name, inactive_m_name, nil, nil, new_height)
      when not is_nil(inactive_m_name),
      do: diff(invalidate1(:inactive, inactive_m_name, new_height))

  def invalidate(_plain_name, nil, active_m_name, nil, new_height)
      when not is_nil(active_m_name),
      do: diff(invalidate1(:active, active_m_name, new_height))

  def invalidate(_plain_name, nil, nil, {_, {_, _}, _, _, [_ | _]} = auction_bid, new_height),
    do: diff(invalidate1(:bid, auction_bid, new_height))

  def invalidate(_plain_name, inactive_m_name, nil, auction_bid, new_height)
      when not is_nil(inactive_m_name) and not is_nil(auction_bid) do
    {dels1, writes1} = invalidate1(:inactive, inactive_m_name, new_height)
    {dels2, writes2} = invalidate1(:bid, auction_bid, new_height)

    diff(
      {merge_maps([dels1, dels2], &uniq_merger/3), merge_maps([writes1, writes2], &uniq_merger/3)}
    )
  end

  def invalidate(_plain_name, inactive_m_name, active_m_name, nil, new_height)
      when not is_nil(inactive_m_name) and not is_nil(active_m_name) do
    {dels1, writes} = invalidate1(:inactive, inactive_m_name, new_height)
    {dels2, ^writes} = invalidate1(:active, active_m_name, new_height)
    diff({merge_maps([dels1, dels2], &uniq_merger/3), writes})
  end

  ##########

  def invalidate1(lfcycle, obj, new_height),
    do: {dels(lfcycle, obj), writes(name_for_epoch(obj, new_height))}

  defp cons_merger(_k, v1, v2), do: v1 ++ v2
  defp uniq_merger(_k, v1, v2), do: Enum.uniq(v1 ++ v2)

  def diff({dels, writes}) do
    {Enum.flat_map(
       dels,
       fn {tab, del_ks} ->
         ws = Map.get(writes, tab, nil)
         finder = fn k -> Enum.find(ws, &(elem(&1, 1) == k)) end
         rem_ks = ws && Enum.reject(del_ks, &finder.(&1))
         rem_nil = is_nil(rem_ks) || rem_ks == []
         (rem_nil && []) || [{tab, rem_ks}]
       end
     )
     |> Enum.into(%{}), writes}
  end

  def dels(lfcycle, obj) do
    plain_name = plain_name(obj)

    map_tabs(
      lfcycle,
      fn -> [{activity_end(obj), plain_name}] end,
      fn -> [plain_name] end,
      fn -> [{owner(obj), plain_name}] end
    )
  end

  def writes(nil), do: %{}

  def writes({lfcycle, obj, expire}) do
    plain_name = plain_name(obj)

    map_tabs(
      lfcycle,
      fn -> [m_exp(expire, plain_name)] end,
      fn -> [(lfcycle == :bid && Model.auction_bid(index: obj)) || obj] end,
      fn -> [Model.owner(index: {owner(obj), plain_name})] end
    )
  end

  def name_for_epoch(nil, _new_height),
    do: nil

  def name_for_epoch({plain_name, bi_txi, auction_end, owner, claims}, new_height) do
    [{{last_claim, _}, _} | _] = claims
    {{first_claim, _}, _} = :lists.last(claims)
    timeout = :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn(new_height))

    cond do
      new_height > last_claim ->
        {:bid, {plain_name, bi_txi, auction_end, owner, claims}, auction_end}

      new_height > first_claim ->
        [{{kbi, _}, last_claim_txi} = bi_txi | _] = claims = drop_bi_txi(claims, new_height)
        owner = Validate.id!(read_raw_tx!(last_claim_txi).tx.account_id)
        auction_end = kbi + timeout
        {:bid, {plain_name, bi_txi, auction_end, owner, claims}, auction_end}

      new_height <= first_claim ->
        map_ok_nil(
          cache_through_read(Model.InactiveName, plain_name),
          &name_for_epoch(&1, new_height)
        )
    end
  end

  def name_for_epoch(m_name, new_height) when Record.is_record(m_name, :name) do
    index = Model.name(m_name, :index)
    active = Model.name(m_name, :active)
    timeout = Model.name(m_name, :auction_timeout)
    [{{last_claim, _}, _} | _] = claims = Model.name(m_name, :claims)
    {{first_claim, _}, _} = :lists.last(claims)

    cond do
      new_height >= active ->
        expire = revoke_or_expire_height(Model.name(m_name, :revoke), Model.name(m_name, :expire))
        lfcycle = (new_height < expire && :active) || :inactive
        updates = drop_bi_txi(Model.name(m_name, :updates), new_height)
        transfers = drop_bi_txi(Model.name(m_name, :transfers), new_height)
        new_expire = new_expire(active, updates, new_height)

        m_name =
          Model.name(
            index: index,
            active: Model.name(m_name, :active),
            expire: new_expire,
            claims: claims,
            updates: updates,
            transfers: transfers,
            revoke: nil,
            auction_timeout: Model.name(m_name, :auction_timeout),
            owner: new_owner(claims, transfers),
            previous: Model.name(m_name, :previous)
          )

        {lfcycle, m_name, new_expire}

      timeout > 0 and new_height >= first_claim and new_height < last_claim + timeout ->
        [{{last_claim, _}, _} = bi_txi | _] = claims = drop_bi_txi(claims, new_height)
        auction_end = last_claim + timeout
        {:bid, {index, bi_txi, auction_end, new_owner(claims, []), claims}, auction_end}

      new_height < first_claim ->
        name_for_epoch(Model.name(m_name, :previous), new_height)
    end
  end

  def map_tabs(:inactive, exp_f, name_f, _owner_f),
    do: %{Model.InactiveNameExpiration => exp_f.(), Model.InactiveName => name_f.()}

  def map_tabs(:active, exp_f, name_f, owner_f),
    do: %{
      Model.ActiveNameExpiration => exp_f.(),
      Model.ActiveName => name_f.(),
      Model.ActiveOwner => owner_f.()
    }

  def map_tabs(:bid, exp_f, bid_f, owner_f),
    do: %{
      Model.AuctionExpiration => exp_f.(),
      Model.AuctionBid => bid_f.(),
      Model.AuctionOwner => owner_f.()
    }

  def m_exp(height, plain_name),
    do: Model.expiration(index: {height, plain_name})

  def owner(m_name) when Record.is_record(m_name, :name), do: Model.name(m_name, :owner)
  def owner({_, _, _, owner, _}), do: owner

  def activity_end(m_name) when Record.is_record(m_name, :name),
    do: revoke_or_expire_height(m_name)

  def activity_end({_, _, auction_end, _, _}),
    do: auction_end

  def plain_name(m_name) when Record.is_record(m_name, :name), do: Model.name(m_name, :index)
  def plain_name({plain_name, {_, _}, _, _, [_ | _]}), do: plain_name

  def new_expire(active, [] = _new_updates, new_height),
    do: active + :aec_governance.name_claim_max_expiration(proto_vsn(new_height))

  def new_expire(_active, [{{height, _}, txi} | _] = _new_updates, _) do
    %{tx: %{name_ttl: ttl, type: :name_update_tx}} = read_raw_tx!(txi)
    height + ttl
  end

  def new_owner(_claims, [{{_, _}, transfer_txi} | _] = _transfers),
    do: Validate.id!(read_raw_tx!(transfer_txi).tx.recipient_id)

  def new_owner([{{_, _}, claim_txi} | _] = _claims, [] = _transfers),
    do: Validate.id!(read_raw_tx!(claim_txi).tx.account_id)

  def pointee_key(ptr, {bi, txi}) do
    {k, v} = Name.pointer_kv(ptr)
    {v, {bi, txi}, k}
  end

  def drop_bi_txi(bi_txis, new_height),
    do: Enum.drop_while(bi_txis, fn {{kbi, _mbi}, _txi} -> kbi >= new_height end)

  def read_raw_tx!(txi),
    do: Format.to_raw_map(read_tx!(txi))

  def read_cached_raw_tx!(txi) do
    case :ets.lookup(:tx_sync_cache, txi) do
      [{^txi, m_tx}] -> Format.to_raw_map(m_tx)
      [] -> read_raw_tx!(txi)
    end
  end
end
