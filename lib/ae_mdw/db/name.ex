defmodule AeMdw.Db.Name do
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.{Model, Format}
  alias AeMdw.Validate

  require Model
  require Ex2ms

  import AeMdw.{Util, Db.Util}

  ##########

  def plain_name(name_hash),
    do: map_one_nil(read(Model.PlainName, name_hash), &{:ok, Model.plain_name(&1, :value)})

  def plain_name!(name_hash),
    do: Model.plain_name(read!(Model.PlainName, name_hash), :value)

  def ptr_resolve!(block_index, name_hash, key) do
    :aens.resolve_hash(key, name_hash, ns_tree!(block_index))
    |> map_ok!(&Validate.id!/1)
  end

  ##########

  def pointer_kv_raw(ptr),
    do: {:aens_pointer.key(ptr), :aens_pointer.id(ptr)}

  def pointer_kv(ptr),
    do: {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}

  def bid_top_key(plain_name),
    do: {plain_name, <<>>, <<>>, <<>>}

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

  def pointers(m_name) do
    case Model.name(m_name, :updates) do
      [{_, txi} | _] ->
        Format.to_raw_map(read_tx!(txi)).tx.pointers
        |> Stream.map(&pointer_kv_raw/1)
        |> Enum.into(%{})

      [] ->
        %{}
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

  def ownership(m_name) do
    [{{_, _}, last_claim_txi} | _] = Model.name(m_name, :claims)
    %{tx: %{account_id: orig_owner}} = Format.to_raw_map(read_tx!(last_claim_txi))

    case Model.name(m_name, :transfers) do
      [] ->
        %{original: orig_owner, current: orig_owner}

      [{{_, _}, last_transfer_txi} | _] ->
        %{tx: %{recipient_id: curr_owner}} = Format.to_raw_map(read_tx!(last_transfer_txi))
        %{original: orig_owner, current: curr_owner}
    end
  end

  def revoke_or_expire_height(m_name) do
    case Model.name(m_name, :revoke) do
      {{height, _}, _} ->
        height

      nil ->
        Model.name(m_name, :expire)
    end
  end

  # for use outside mnesia TX - doesn't modify cache, just looks into it
  def cache_through_read(table, key) do
    case :ets.lookup(:sync_cache, {table, key}) do
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
    lookup.(:ets.prev(:sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  # for use inside mnesia TX - caches writes & deletes in the same TX
  def cache_through_write(table, record) do
    :ets.insert(:sync_cache, {{table, elem(record, 1)}, record})
    :mnesia.write(table, record, :write)
  end

  def cache_through_delete(table, key) do
    :ets.delete(:sync_cache, {table, key})
    :mnesia.delete(table, key, :write)
  end

  def cache_through_delete_inactive(nil), do: nil

  def cache_through_delete_inactive(m_name) do
    plain_name = Model.name(m_name, :index)
    expire = revoke_or_expire_height(m_name)
    cache_through_delete(Model.InactiveName, plain_name)
    cache_through_delete(Model.InactiveNameExpiration, {expire, plain_name})
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
    do: elem(ns_tree, AE.ns_tree_pos(:mtree))

  def mtree({_, _} = block_index),
    do: mtree(ns_tree!(block_index))

  def cache(ns_tree) when elem(ns_tree, 0) == :ns_tree,
    do: elem(ns_tree, AE.ns_tree_pos(:cache))

  def cache({_, _} = block_index),
    do: cache(ns_tree!(block_index))
end
