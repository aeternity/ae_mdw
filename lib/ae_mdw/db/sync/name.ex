defmodule AeMdw.Db.Sync.Name do
  # credo:disable-for-this-file
  alias AeMdw.Blocks
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.TxnMutation
  alias AeMdw.Db.Name
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Node
  alias AeMdw.Log
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Record
  require Model
  require Ex2ms

  import AeMdw.Db.Name,
    only: [
      cache_through_read!: 3,
      cache_through_read: 2,
      cache_through_read: 3,
      cache_through_write: 3,
      cache_through_delete: 3,
      deactivate_name: 3,
      revoke_or_expire_height: 1
    ]

  import AeMdw.Db.Util
  import AeMdw.Ets
  import AeMdw.Util

  @spec name_claim_mutations(Node.tx(), Txs.tx_hash(), Blocks.block_index(), Txs.txi()) :: [
          TxnMutation.t()
        ]
  def name_claim_mutations(tx, tx_hash, {height, _mbi} = block_index, txi) do
    plain_name = String.downcase(:aens_claim_tx.name(tx))
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    owner_pk = Validate.id!(:aens_claim_tx.account_id(tx))
    name_fee = :aens_claim_tx.name_fee(tx)
    proto_vsn = proto_vsn(height)
    is_lima? = proto_vsn >= Node.lima_vsn()
    timeout = :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)

    [
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        is_lima?,
        txi,
        block_index,
        timeout
      )
      | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
    ]
  end

  def update(txn, name_hash, delta_ttl, pointers, txi, {height, _mbi} = bi, internal?) do
    plain_name = plain_name!(txn, name_hash)
    m_name = cache_through_read!(txn, Model.ActiveName, plain_name)
    old_expire = Model.name(m_name, :expire)
    new_expire = height + delta_ttl
    updates = [{bi, txi} | Model.name(m_name, :updates)]
    new_m_name_exp = Model.expiration(index: {new_expire, plain_name})
    new_m_name = Model.name(m_name, expire: new_expire, updates: updates)

    for ptr <- pointers do
      m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi}))
      cache_through_write(txn, Model.Pointee, m_pointee)
    end

    cond do
      delta_ttl > 0 ->
        cache_through_delete(txn, Model.ActiveNameExpiration, {old_expire, plain_name})
        cache_through_write(txn, Model.ActiveNameExpiration, new_m_name_exp)
        cache_through_write(txn, Model.ActiveName, new_m_name)

        log_name_change(height, plain_name, "extend")

      delta_ttl == 0 and not internal? ->
        deactivate_name(txn, height, new_m_name)

        inc(:stat_sync_cache, :names_expired)

        log_name_change(height, plain_name, "expire")

      true ->
        if internal? do
          m_name = Model.name(m_name, updates: updates)
          cache_through_write(txn, Model.ActiveName, m_name)
        end

        log_name_change(height, plain_name, "delta_ttl #{delta_ttl} NA")
    end
  end

  def transfer(txn, name_hash, new_owner, txi, {height, _mbi} = bi) do
    plain_name = plain_name!(txn, name_hash)

    m_name = cache_through_read!(txn, Model.ActiveName, plain_name)
    old_owner = Model.name(m_name, :owner)

    transfers = [{bi, txi} | Model.name(m_name, :transfers)]
    m_name = Model.name(m_name, transfers: transfers, owner: new_owner)
    m_owner = Model.owner(index: {new_owner, plain_name})

    cache_through_delete(txn, Model.ActiveNameOwner, {old_owner, plain_name})
    cache_through_write(txn, Model.ActiveNameOwner, m_owner)
    cache_through_write(txn, Model.ActiveName, m_name)

    log_name_change(height, plain_name, "transfer")
  end

  def revoke(txn, name_hash, txi, {height, _mbi} = bi) do
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(txn, Model.ActiveName, plain_name)
    m_name = Model.name(m_name, revoke: {bi, txi})
    deactivate_name(txn, height, m_name)

    inc(:stat_sync_cache, :names_revoked)

    log_name_change(height, plain_name, "revoke")
  end

  ##########

  def plain_name!(name_hash) do
    {:ok, m_plain_name} = cache_through_read(Model.PlainName, name_hash)

    Model.plain_name(m_plain_name, :value)
  end

  defp plain_name!(txn, name_hash) do
    {:ok, m_plain_name} = cache_through_read(txn, Model.PlainName, name_hash)

    Model.plain_name(m_plain_name, :value)
  end

  def log_name_change(height, plain_name, change),
    do: Log.info("[#{height}][name] #{change} #{plain_name}")

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
        expire = revoke_or_expire_height(m_name)
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
    {k, v} = pointer_kv(ptr)
    {v, {bi, txi}, k}
  end

  defp pointer_kv(ptr) do
    {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}
  end

  def drop_bi_txi(bi_txis, new_height),
    do: Enum.drop_while(bi_txis, fn {{kbi, _mbi}, _txi} -> kbi >= new_height end)

  def read_raw_tx!(txi),
    do: Format.to_raw_map(read_tx!(txi))
end
