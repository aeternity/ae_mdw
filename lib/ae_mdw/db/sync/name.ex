defmodule AeMdw.Db.Sync.Name do
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.{Name, Model, Format}
  alias AeMdw.Log

  require Record
  require Model
  require Ex2ms

  import AeMdw.Db.Name,
    only: [cache_through_read!: 2, cache_through_read: 2,
           cache_through_prev: 2, cache_through_write: 2,
           cache_through_delete: 2, cache_through_delete_inactive: 1,
           revoke_or_expire_height: 1, source: 2]

  import AeMdw.{Util, Db.Util}

  ##########

  def claim(plain_name, name_hash, _tx, txi, {height, _} = bi) do
    m_plain_name = Model.plain_name(index: name_hash, value: plain_name)
    cache_through_write(Model.PlainName, m_plain_name)

    proto_vsn = (height >= AE.lima_height() && AE.lima_vsn()) || 0

    case :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn) do
      0 ->
        previous = ok_nil(cache_through_read(Model.InactiveName, plain_name))
        expire = height + :aec_governance.name_claim_max_expiration()
        m_name = Model.name(
          index: plain_name,
          active: height,
          expire: expire,
          claims: [{bi, txi}],
          previous: previous
        )
        m_name_exp = Model.expiration(index: {expire, plain_name})
        cache_through_write(Model.ActiveName, m_name)
        cache_through_write(Model.ActiveNameExpiration, m_name_exp)
        cache_through_delete_inactive(previous)

      timeout ->
        auction_end = height + timeout
        m_auction_exp = Model.expiration(index: {auction_end, plain_name}, value: timeout)
        make_m_bid = &Model.auction_bid(index: {plain_name, {bi, txi}, auction_end, &1})

        m_bid =
          case cache_through_prev(Model.AuctionBid, Name.bid_top_key(plain_name)) do
            :not_found ->
              make_m_bid.([{bi, txi}])

            {:ok, {^plain_name, _prev_bi_txi, prev_auction_end, prev_bids} = prev_key} ->
              cache_through_delete(Model.AuctionBid, prev_key)
              cache_through_delete(Model.AuctionExpiration, {prev_auction_end, plain_name})
              make_m_bid.([{bi, txi} | prev_bids])
          end

        cache_through_write(Model.AuctionBid, m_bid)
        cache_through_write(Model.AuctionExpiration, m_auction_exp)
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
    cache_through_delete(Model.ActiveNameExpiration, {old_expire, plain_name})
    cache_through_write(Model.ActiveNameExpiration, m_name_exp)

    m_name = Model.name(m_name, expire: new_expire, updates: updates)
    cache_through_write(Model.ActiveName, m_name)

    for ptr <- pointers do
      m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi}))
      cache_through_write(Model.Pointee, m_pointee)
    end
  end


  def transfer(name_hash, _tx, txi, {_height, _} = bi) do
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(Model.ActiveName, plain_name)
    transfers = [{bi, txi} | Model.name(m_name, :transfers)]
    m_name = Model.name(m_name, transfers: transfers)
    cache_through_write(Model.ActiveName, m_name)
  end


  def revoke(name_hash, _tx, txi, {height, _} = bi) do
    plain_name = plain_name!(name_hash)

    m_name = cache_through_read!(Model.ActiveName, plain_name)
    expire = Model.name(m_name, :expire)
    cache_through_delete(Model.ActiveNameExpiration, {expire, plain_name})
    cache_through_delete(Model.ActiveName, plain_name)

    m_name = Model.name(m_name, revoke: {bi, txi})
    m_exp = Model.expiration(index: {height, plain_name})
    cache_through_write(Model.InactiveName, m_name)
    cache_through_write(Model.InactiveNameExpiration, m_exp)
  end

  ##########

  def expire(height) do
    name_mspec = Ex2ms.fun do {:expiration, {^height, name}, :_} -> name end
    :mnesia.select(Model.ActiveNameExpiration, name_mspec)
    |> Enum.each(&expire_name(height, &1))

    auction_mspec = Ex2ms.fun do {:expiration, {^height, name}, tm} -> {name, tm} end
    :mnesia.select(Model.AuctionExpiration, auction_mspec)
    |> Enum.each(fn {name, timeout} -> expire_auction(height, name, timeout) end)
  end

  def expire_name(height, plain_name) do
    m_name = cache_through_read!(Model.ActiveName, plain_name)
    m_exp = Model.expiration(index: {height, plain_name})
    cache_through_write(Model.InactiveName, m_name)
    cache_through_write(Model.InactiveNameExpiration, m_exp)
    cache_through_delete(Model.ActiveName, plain_name)
    cache_through_delete(Model.ActiveNameExpiration, {height, plain_name})
    log_expired_name(height, plain_name)
  end

  def expire_auction(height, plain_name, timeout) do
    {_, _, _, bids} = bid_key =
      ok!(cache_through_prev(Model.AuctionBid, Name.bid_top_key(plain_name)))

    previous = ok_nil(cache_through_read(Model.InactiveName, plain_name))
    expire = height + :aec_governance.name_claim_max_expiration()
    m_name = Model.name(
      index: plain_name,
      active: height,
      expire: expire,
      claims: bids,
      auction_timeout: timeout,
      previous: previous
    )
    m_name_exp = Model.expiration(index: {expire, plain_name})
    cache_through_write(Model.ActiveName, m_name)
    cache_through_write(Model.ActiveNameExpiration, m_name_exp)
    cache_through_delete(Model.AuctionExpiration, {height, plain_name})
    cache_through_delete(Model.AuctionBid, bid_key)
    cache_through_delete_inactive(previous)
    log_expired_auction(height, m_name)
  end

  ##########

  def plain_name!(name_hash),
    do: cache_through_read!(Model.PlainName, name_hash) |> Model.plain_name(:value)

  def log_expired_name(height, plain_name),
    do: Log.info("[#{height}] #{inspect :erlang.timestamp()} expiring name #{plain_name}")

  def log_expired_auction(height, m_name) do
    plain_name = Model.name(m_name, :index)
    Log.info("[#{height}] #{inspect :erlang.timestamp()} expiring auction for #{plain_name}")
  end

  ################################################################################
  #
  # NEEDS REWORK!
  #
  # stub for now

  def invalidate(_type_txis, _new_height),
    do: {%{}, %{}}



 #  # name_txis - must be from newest first to oldest
 #  def invalidate(type_txis, new_height) do
 #    cons_merger = fn _, vs1, vs2 -> [vs1 | vs2] end
 #    invalidate_name = fn m_name, source, txs ->
 #      plain_name = Model.name(m_name, :index)
 #      case Model.name(m_name, :auction_timeout) do
 #        0 -> invalidate_simple_name(plain_name, m_name, source, txs, new_height)
 #        _ -> invalidate_auction_name(plain_name, m_name, source, txs, new_height)
 #      end
 #    end

 #    {all_dels_nested, all_writes_nested} =
 #      type_txis
 #      |> Stream.map(fn {_type, txi} -> read_raw_tx!(txi) end)
 #      |> Enum.group_by(& &1.tx.name)
 #      |> Enum.reduce({%{}, %{}},
 #           fn {plain_name, txs}, {all_dels, all_writes} ->
 #             txs = Enum.group_by(txs, & &1.tx.type)
 #             {dels, writes} =
 #               case Name.locate(plain_name) do
 #                 {m_name, Model.InactiveName = source} when Record.is_record(m_name, :name) ->
 #                   case Name.locate_bid(plain_name) do
 #                     nil ->
 #                       invalidate_name.(m_name, source, txs)
 #                     bid ->
 #                       invalidate_inactive_name_and_auction_bid(
 #                         plain_name, m_name, bid, txs, new_height)
 #                   end

 #                 {m_name, Model.ActiveName = source} when Record.is_record(m_name, :name) ->
 #                   invalidate_name.(m_name, source, txs)

 #                 {bid, Model.AuctionBid} ->
 #                   invalidate_auction_bid(plain_name, bid, txs, new_height)
 #               end

 #             {merge_maps([all_dels, dels], cons_merger),
 #              merge_maps([all_writes, writes], cons_merger)}
 #           end)

 #    {flatten_map_values(all_dels_nested),
 #     flatten_map_values(all_writes_nested)}
 #  end


 #  def invalidate_simple_name(plain_name, m_name, Model.ActiveName, txs, new_height) do
 #    nil = revoke(txs)
 #    update_txs = updates(txs)
 #    expire = revoke_or_expire_height(m_name)

 #    case {claims(txs), update_txs} do
 #      {[], [_|_]} ->
 #        # reverting updates, transfers, revoke
 #        {new_m_name, new_m_name_exp} = new_m_name(m_name, txs)
 #        {%{Model.Pointee => pointee_dels(update_txs),
 #           Model.ActiveNameExpiration => [{expire, plain_name}]},
 #         %{Model.ActiveName => [new_m_name],
 #           Model.ActiveNameExpiration => [new_m_name_exp]}}

 #      {[], []} ->
 #        # reverting transfers, revoke
 #        new_transfers = drop_bi_txis(transfers(m_name), transfers(txs))
 #        new_m_name = Model.name(m_name, transfers: new_transfers)
 #        {%{}, %{Model.ActiveName => [new_m_name]}}

 #      {_, _} ->
 #        # reverting claim (or all-claims for auctioned name)
 #        {%{Model.Pointee => pointee_dels(plain_name, new_height),
 #           Model.ActiveName => [plain_name],
 #           Model.ActiveNameExpiration => [{expire, plain_name}]},
 #         prevs_writes(chase_prevs(m_name), new_height)}
 #    end
 #  end

 # def invalidate_simple_name(plain_name, m_name, Model.InactiveName, txs, new_height) do
 #    update_txs = updates(txs)
 #    expire = revoke_or_expire_height(m_name)
 #    dels = fn pointee_dels ->
 #      %{Model.Pointee => pointee_dels,
 #        Model.InactiveName => [plain_name],
 #        Model.InactiveNameExpiration => [{expire, plain_name}]}
 #    end

 #    case claims(txs) do
 #      [] ->
 #        # reverting updates, transfers, revoke
 #        {new_m_name, new_m_name_exp} = new_m_name(m_name, txs)
 #        {dels.(pointee_dels(update_txs)),
 #         %{Model.ActiveName => [new_m_name],
 #           Model.ActiveNameExpiration => [new_m_name_exp]}}

 #      _ ->
 #        # reverting claim (or all-claims for auctioned name)
 #        {dels.(pointee_dels(plain_name, new_height)),
 #         prevs_writes(chase_prevs(m_name), new_height)}
 #    end
 #  end


 #  def invalidate_auction_name(plain_name, m_name, source, txs, new_height) do
 #    active = Model.name(m_name, :active)

 #    case claims(txs) do
 #      [] when new_height >= active ->
 #        # no claims, fork after name activated - invalidation as for simple name
 #        invalidate_simple_name(plain_name, m_name, source, txs, new_height)

 #      claim_txs ->
 #        expire = revoke_or_expire_height(m_name)
 #        timeout = Model.name(m_name, :auction_timeout)
 #        dels = fn pointee_dels ->
 #          %{Model.Pointee => pointee_dels,
 #            Name.source(source, :name) => [plain_name],
 #            Name.source(source, :expiration) => [{expire, plain_name}]}
 #        end

 #        case drop_bi_txis(claims(m_name), claim_txs) do
 #          [] ->
 #            # all claims reverted
 #            {dels.(pointee_dels(plain_name, new_height)),
 #             prevs_writes(chase_prevs(m_name), new_height)}

 #          [_|_] = bids when new_height < active ->
 #            # we are in auction again
 #            {dels.(pointee_dels(updates(txs))),
 #             auction_writes(plain_name, bids, timeout)}
 #        end
 #    end
 #  end


 #  def invalidate_auction_bid(plain_name, bid, txs, new_height) do
 #    {_, {{height0, _}, _}, auction_end0, prev_bids} = bid
 #    dels = %{Model.AuctionBid => [bid],
 #             Model.AuctionExpiration => [{auction_end0, plain_name}]}
 #    case drop_bi_txis(prev_bids, claims(txs)) do
 #      [] ->
 #        # all claims removed - auction doesn't exist anymore
 #        {dels, %{}}

 #      [_|_] = bids ->
 #        # some claims removed - in auction again
 #        timeout = auction_end0 - height0
 #        {dels, auction_writes(plain_name, bids, timeout)}
 #    end
 #  end

 #  def invalidate_inactive_name_and_auction_bid(plain_name, m_name, bid, txs, new_height) do

 #    # {_, {{_, _}, _}, _, prev_bids} = bid
 #    # {{_first_bid, _}, first_bid_txi} = :lists.last(prev_bids)

 #    # {inactive_name_txs, bid_txs} = partition_txs(txs, & &1.tx_index < first_bid_txi)

 #    # case {map_size(inactive_name_txs), map_size(bid_txs)} do
 #    #   {0, _} ->
 #    #     {dels, writes} = invalidate_auction_bid(plain_name, bid, bid_txs, new_height)
 #    #     case map_size(writes) do
 #    #       0 -> # whole auction gone, we need to check in inactive isn't



 #    #   {_, 0} ->
 #    #     :todo

 #    #   {_, _} ->


 #  end

 #  ####

 #  def claims(n) when Record.is_record(n, :name), do: Model.name(n, :claims)
 #  def claims(%{} = m), do: Map.get(m, :name_claim_tx, [])

 #  def updates(n) when Record.is_record(n, :name), do: Model.name(n, :updates)
 #  def updates(%{} = m), do: Map.get(m, :name_update_tx, [])

 #  def transfers(n) when Record.is_record(n, :name), do: Model.name(n, :transfers)
 #  def transfers(%{} = m), do: Map.get(m, :name_transfer_tx, [])

 #  def revoke(n) when Record.is_record(n, :name), do: Model.name(n, :revoke)
 #  def revoke(%{} = m), do: one(Map.get(m, :name_revoke_tx, []))

 #  def partition_txs(txs, splitter) do
 #    Enum.reduce(txs, {%{}, %{}},
 #      fn {k, vs}, {m1, m2} ->
 #        {before_h, after_h} = Enum.split_with(vs, splitter)
 #        {before_h == [] && m1 || Map.put(m1, k, before_h),
 #         after_h == [] && m2 || Map.put(m2, k, after_h)}
 #      end)
 #  end

 #  def new_expire(m_name, []),
 #    do: Model.name(m_name, :active) + :aec_governance.name_claim_max_expiration()
 #  def new_expire(_m_name, [{{height, _}, txi} | _] = _new_updates) do
 #    %{tx: %{name_ttl: ttl, type: :name_update_tx}} = read_raw_tx!(txi)
 #    height + ttl
 #  end

 #  def new_m_name(m_name, txs) do
 #    plain_name = Model.name(m_name, :index)
 #    new_updates = drop_bi_txis(updates(m_name), updates(txs))
 #    new_transfers = drop_bi_txis(transfers(m_name), transfers(txs))
 #    new_expire = new_expire(m_name, new_updates)
 #    {Model.name(m_name,
 #        expire: new_expire,
 #        updates: new_updates,
 #        transfers: new_transfers,
 #        revoke: nil),
 #     Model.expiration(index: {new_expire, plain_name})}
 #  end


 #  def auction_writes(plain_name, [{{height, _mbi}, _txi} = bi_txi | _] = bids, timeout) do
 #    auction_end = height + timeout
 #    m_auction_exp = Model.expiration(index: {auction_end, plain_name}, value: timeout)
 #    m_bid = Model.auction_bid(index: {plain_name, bi_txi, auction_end, bids})
 #    %{Model.AuctionBid => [m_bid],
 #      Model.AuctionExpiration => [m_auction_exp]}
 #  end


 #  def chase_prevs(m_name) do
 #    succ = &Model.name(&1, :previous)
 #    root = succ.(m_name)
 #    root && chase(root, succ) || []
 #  end

 #  def prevs_writes([], _new_height),
 #    do: %{}
 #  def prevs_writes([top | _] = prevs, new_height) do
 #    plain_name = Model.name(top, :index)

 #    simple_writes = fn m_name, name_tab ->
 #      new_expire = Model.name(m_name, :expire)
 #      %{source(name_tab, :name) => [m_name],
 #        source(name_tab, :expiration) => [Model.expiration(index: {new_expire, plain_name})]}
 #    end

 #    Enum.reduce_while(prevs, %{},
 #      fn m_name, %{} ->
 #        active = Model.name(m_name, :active)
 #        expire = revoke_or_expire_height(m_name)
 #        claims = Model.name(m_name, :claims)
 #        {{first_claim, _}, _} = :lists.last(claims)
 #        timeout = Model.name(m_name, :auction_timeout)

 #        cond do
 #          new_height < first_claim ->
 #            {:cont, %{}}
 #          new_height >= expire ->
 #            {:halt, simple_writes.(m_name, Model.InactiveName)}
 #          new_height >= active ->
 #            {:halt, simple_writes.(m_name, Model.ActiveName)}
 #          timeout > 0 ->
 #            [{{last_bid, _}, _} = bi_txi | _] = bids =
 #              Enum.drop_while(claims, fn {{h, _}, _} -> h >= new_height end)

 #            auction_end = last_bid + timeout
 #            m_auction_exp = Model.expiration(index: {auction_end, plain_name}, value: timeout)
 #            m_bid = Model.auction_bid(index: {plain_name, bi_txi, auction_end, bids})
 #            {:halt, %{Model.AuctionBid => [m_bid],
 #                      Model.AuctionExpiration => [m_auction_exp]}}
 #        end
 #      end)
 #  end


 #  def pointee_dels(plain_name, new_height) do
 #    scope = {:gen, last_gen()..new_height}
 #    query = [name: plain_name, type: :name_update]
 #    pointee_dels(AeMdw.Db.Stream.map(scope, :raw, query))
 #  end

 #  def pointee_dels(inv_update_txs) do
 #    Enum.flat_map(inv_update_txs,
 #      fn %{tx: %{type: :name_update_tx, pointers: ptrs}} = tx ->
 #        Enum.map(ptrs, &pointee_key(&1, bi_txi(tx)))
 #      end)
 #  end

  def pointee_key(ptr, {bi, txi}) do
    {k, v} = Name.pointer_kv(ptr)
    {v, {bi, txi}, k}
  end


 #  def bi_txi(%{block_height: kbi, micro_index: mbi, tx_index: txi}),
 #    do: {{kbi, mbi}, txi}

 #  def drop_bi_txis(bi_txis, []),
 #    do: bi_txis
 #  def drop_bi_txis([{{kbi, mbi}, txi} | rem_bi_txis],
 #                    [%{block_height: kbi, micro_index: mbi, tx_index: txi} | rem_txs]),
 #    do: drop_bi_txis(rem_bi_txis, rem_txs)


 #  def read_raw_tx!(txi),
 #    do: Format.to_raw_map(read_tx!(txi))


end
