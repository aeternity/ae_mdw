defmodule AeMdw.Db.Name do
  # credo:disable-for-this-file
  alias AeMdw.Blocks
  alias AeMdw.Contracts
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Ets
  alias AeMdw.Log
  alias AeMdw.Names
  alias AeMdw.Validate

  require Ex2ms
  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  ##########

  def plain_name(name_hash),
    do: map_one_nil(read(Model.PlainName, name_hash), &{:ok, Model.plain_name(&1, :value)})

  def plain_name!(name_hash),
    do: Model.plain_name(read!(Model.PlainName, name_hash), :value)

  def ptr_resolve!(block_index, name_hash, key) do
    :aens.resolve_hash(key, name_hash, ns_tree!(block_index))
    |> map_ok!(&Validate.id!/1)
  end

  def owned_by(owner_pk, _active? = true) do
    %{
      names: collect_vals(Model.ActiveNameOwner, owner_pk),
      top_bids: collect_vals(Model.AuctionOwner, owner_pk)
    }
  end

  def owned_by(owner_pk, _active? = false) do
    %{
      names: collect_vals(Model.InactiveNameOwner, owner_pk)
    }
  end

  @spec expire_after(Blocks.height()) :: Blocks.height()
  def expire_after(auction_end) do
    auction_end + :aec_governance.name_claim_max_expiration(proto_vsn(auction_end))
  end

  @spec expirations_mutation(Blocks.height()) :: NamesExpirationMutation.t()
  def expirations_mutation(height) do
    name_mspec =
      Ex2ms.fun do
        Model.expiration(index: {^height, name}) -> name
      end

    auction_mspec =
      Ex2ms.fun do
        Model.expiration(index: {^height, name}, value: tm) -> {name, tm}
      end

    {:atomic, {expired_names, expired_auctions}} =
      :mnesia.transaction(fn ->
        names = :mnesia.select(Model.ActiveNameExpiration, name_mspec)
        auctions = :mnesia.select(Model.AuctionExpiration, auction_mspec)

        {names, auctions}
      end)

    NamesExpirationMutation.new(height, expired_names, expired_auctions)
  end

  @spec expire_name(Blocks.height(), Names.plain_name()) :: :ok
  def expire_name(height, plain_name) do
    m_name = cache_through_read!(Model.ActiveName, plain_name)
    m_exp = Model.expiration(index: {height, plain_name})

    if Model.name(m_name, :expire) == height do
      owner = Model.name(m_name, :owner)
      cache_through_write(Model.InactiveName, m_name)
      cache_through_write(Model.InactiveNameOwner, Model.owner(index: {owner, plain_name}))
      cache_through_write(Model.InactiveNameExpiration, m_exp)
      cache_through_delete(Model.ActiveName, plain_name)
      cache_through_delete(Model.ActiveNameOwner, {owner, plain_name})
      cache_through_delete(Model.ActiveNameExpiration, {height, plain_name})
      Ets.inc(:stat_sync_cache, :inactive_names)
      Ets.dec(:stat_sync_cache, :active_names)
      Log.info("[#{height}] expiring name #{plain_name}")
    else
      cache_through_delete(Model.ActiveNameExpiration, {height, plain_name})

      Log.info("[#{height}][name] old expire #{plain_name}")
    end
  end

  @spec expire_auction(Blocks.height(), Names.plain_name(), Names.auction_timeout()) :: :ok
  def expire_auction(height, plain_name, timeout) do
    {_, {_, txi}, _, owner, bids} =
      bid_key = ok!(cache_through_prev(Model.AuctionBid, bid_top_key(plain_name)))

    previous = ok_nil(cache_through_read(Model.InactiveName, plain_name))
    expire = expire_after(height)

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

    cache_through_write(Model.ActiveName, m_name)
    cache_through_write(Model.ActiveNameOwner, m_owner)
    cache_through_write(Model.ActiveNameExpiration, m_name_exp)
    cache_through_delete(Model.AuctionExpiration, {height, plain_name})
    cache_through_delete(Model.AuctionOwner, {owner, plain_name})
    cache_through_delete(Model.AuctionBid, bid_key)
    cache_through_delete_inactive(previous)

    %{tx: winning_tx} = read_raw_tx!(txi)
    IntTransfer.fee({height, -1}, :lock_name, owner, txi, winning_tx.name_fee)
    Ets.inc(:stat_sync_cache, :active_names)
    Ets.dec(:stat_sync_cache, :active_auctions)
    Log.info("[#{height}] expiring auction for #{plain_name}")
  end

  ##########

  def pointer_kv_raw(ptr),
    do: {:aens_pointer.key(ptr), :aens_pointer.id(ptr)}

  def pointer_kv(ptr),
    do: {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}

  def bid_top_key(plain_name),
    do: {plain_name, <<>>, <<>>, <<>>, <<>>}

  def auction_bid_key({:expiration, {_, plain_name}, _}) when is_binary(plain_name),
    do: auction_bid_key(plain_name)

  def auction_bid_key(plain_name) when is_binary(plain_name),
    do: ok_nil(cache_through_prev(Model.AuctionBid, bid_top_key(plain_name)))

  def source(Model.ActiveName, :name), do: Model.ActiveName
  def source(Model.ActiveName, :expiration), do: Model.ActiveNameExpiration
  def source(Model.InactiveName, :name), do: Model.InactiveName
  def source(Model.InactiveName, :expiration), do: Model.InactiveNameExpiration

  def locate_bid(plain_name),
    do: ok_nil(cache_through_prev(Model.AuctionBid, bid_top_key(plain_name)))

  def locate(plain_name) do
    map_ok_nil(cache_through_read(Model.ActiveName, plain_name), &{&1, Model.ActiveName}) ||
      map_ok_nil(cache_through_read(Model.InactiveName, plain_name), &{&1, Model.InactiveName}) ||
      map_some(locate_bid(plain_name), &{&1, Model.AuctionBid})
  end

  def pointers(Model.name(updates: [])), do: %{}

  def pointers(Model.name(index: plain_name, updates: [{_block_index, txi} | _rest_updates])) do
    Model.tx(id: tx_hash) = read_tx!(txi)
    name_hash = :aens.get_name_hash(plain_name)

    pointers =
      case AE.Db.get_tx_data(tx_hash) do
        {_block_hash, :name_update_tx, _signed_tx, tx_rec} ->
          :aens_update_tx.pointers(tx_rec)

        {_block_hash, :contract_call_tx, _signed_tx, _tx_rec} ->
          txi
          |> Contracts.fetch_int_contract_calls("AENS.update")
          |> Stream.map(fn Model.int_contract_call(tx: aetx) ->
            {:name_update_tx, tx} = :aetx.specialize_type(aetx)

            tx
          end)
          |> Enum.find(fn tx ->
            :aens_update_tx.name_hash(tx) == name_hash
          end)
          |> :aens_update_tx.pointers()
      end

    pointers
    |> Stream.map(&pointer_kv_raw/1)
    |> Enum.into(%{})
  end

  def account_pointer_at(plain_name, time_reference_txi) do
    case locate(plain_name) do
      {nil, _module} ->
        {:error, :name_not_found}

      {m_name, _module} ->
        pointee_at(m_name, time_reference_txi)
    end
  end

  def pointee_keys(pk) do
    mspec =
      Ex2ms.fun do
        {:pointee, {^pk, {bi, txi}, k}, :_} -> {bi, txi, k}
      end

    :mnesia.dirty_select(Model.Pointee, mspec)
  end

  def pointees(pk) do
    push = fn place, m_name, {update_bi, update_txi, ptr_k} ->
      pointee = %{
        name: Model.name(m_name, :index),
        active_from: Model.name(m_name, :active),
        expire_height: revoke_or_expire_height(m_name),
        update: Format.to_raw_map({update_bi, update_txi})
      }

      Map.update(place, ptr_k, [pointee], fn pointees -> [pointee | pointees] end)
    end

    for {_bi, txi, _ptr_k} = p_keys <- pointee_keys(pk), reduce: {%{}, %{}} do
      {active, inactive} ->
        %{tx: %{name: plain}} = Format.to_raw_map(read_tx!(txi))

        case locate(plain) do
          {_bid_key, Model.AuctionBid} ->
            {active, inactive}

          {m_name, Model.ActiveName} ->
            {push.(active, m_name, p_keys), inactive}

          {m_name, Model.InactiveName} ->
            {active, push.(inactive, m_name, p_keys)}
        end
    end
  end

  def ownership(
        Model.name(
          claims: [{{_height, _mbi}, last_claim_txi} | _other],
          transfers: transfers,
          owner: owner
        )
      ) do
    %{tx: %{account_id: orig_owner}} = Format.to_raw_map(read_tx!(last_claim_txi))

    case List.first(transfers) do
      nil ->
        %{original: orig_owner, current: orig_owner}

      _any_transfer ->
        %{original: orig_owner, current: :aeser_api_encoder.encode(:account_pubkey, owner)}
    end
  end

  def revoke_or_expire_height(nil = _revoke, expire),
    do: expire

  def revoke_or_expire_height({{height, _}, _}, _expire),
    do: height

  def revoke_or_expire_height(m_name),
    do: revoke_or_expire_height(Model.name(m_name, :revoke), Model.name(m_name, :expire))

  # for use outside mnesia TX - doesn't modify cache, just looks into it
  def cache_through_read(table, key) do
    case :ets.lookup(:name_sync_cache, {table, key}) do
      [{_, record}] -> {:ok, record}
      [] -> map_one_nil(read(table, key), &{:ok, &1})
    end
  end

  def cache_through_read!(table, key),
    do: ok_nil(cache_through_read(table, key)) || raise("#{inspect(key)} not found in #{table}")

  def cache_through_prev(table, key),
    do: cache_through_prev(table, key, &(elem(key, 0) == elem(&1, 0)))

  def cache_through_prev(table, key, key_checker) do
    lookup = fn k, unwrap, eot, chk_fail ->
      case k do
        :"$end_of_table" ->
          eot.()

        prev_key ->
          prev_key = unwrap.(prev_key)
          (key_checker.(prev_key) && {:ok, prev_key}) || chk_fail.()
      end
    end

    nf = fn -> :not_found end
    mns_lookup = fn -> lookup.(prev(table, key), & &1, nf, nf) end
    lookup.(:ets.prev(:name_sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  # for use inside mnesia TX - caches writes & deletes in the same TX
  def cache_through_write(table, record) do
    :ets.insert(:name_sync_cache, {{table, elem(record, 1)}, record})
    :mnesia.write(table, record, :write)
  end

  def cache_through_delete(table, key) do
    :ets.delete(:name_sync_cache, {table, key})
    :mnesia.delete(table, key, :write)
  end

  def cache_through_delete_inactive(nil), do: nil

  def cache_through_delete_inactive(Model.name(index: plain_name, owner: owner_pk) = m_name) do
    expire = revoke_or_expire_height(m_name)
    cache_through_delete(Model.InactiveName, plain_name)
    cache_through_delete(Model.InactiveNameOwner, {owner_pk, plain_name})
    cache_through_delete(Model.InactiveNameExpiration, {expire, plain_name})
  end

  def collect_vals(tab, key) do
    collect_keys(tab, [], {key, ""}, &next/2, fn
      {^key, val}, acc -> {:cont, [val | acc]}
      {_, _}, acc -> {:halt, acc}
    end)
  end

  ##########

  def ns_tree!({_, _} = block_index) do
    block_index
    |> read_block!
    |> Model.block(:hash)
    |> :aec_db.get_block_state()
    |> :aec_trees.ns()
  end

  def mtree(ns_tree) when elem(ns_tree, 0) == :ns_tree,
    do: elem(ns_tree, AE.aens_tree_pos(:mtree))

  def mtree({_, _} = block_index),
    do: mtree(ns_tree!(block_index))

  def cache(ns_tree) when elem(ns_tree, 0) == :ns_tree,
    do: elem(ns_tree, AE.aens_tree_pos(:cache))

  def cache({_, _} = block_index),
    do: cache(ns_tree!(block_index))

  #
  # Private functions
  #
  defp pointee_at(Model.name(index: name, updates: updates), ref_txi) do
    updates
    |> find_update_txi_before(ref_txi)
    |> case do
      nil ->
        {:error, {:pointee_not_found, name, ref_txi}}

      update_txi ->
        {:id, :account, pointee_pk} =
          update_txi
          |> read_tx!()
          |> Format.to_raw_map()
          |> get_in([:tx, :pointers])
          |> Enum.into(%{}, &pointer_kv_raw/1)
          |> Map.get("account_pubkey")

        {:ok, pointee_pk}
    end
  end

  defp find_update_txi_before(updates, ref_txi) do
    Enum.find_value(updates, fn {_block_height, update_txi} ->
      if update_txi <= ref_txi, do: update_txi
    end)
  end

  def read_raw_tx!(txi),
    do: Format.to_raw_map(read_tx!(txi))
end
