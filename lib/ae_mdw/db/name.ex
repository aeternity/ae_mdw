defmodule AeMdw.Db.Name do
  @moduledoc """
  Retrieves name information from database in regards to:
    - name state
    - expiration
    - plain_name
    - owner
    - pointee
    - auction_bid

  All name related data models are read and written by cache through operations.
  """
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Contracts
  alias AeMdw.Database
  alias AeMdw.Node, as: AE
  alias AeMdw.Node.Db
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State
  alias AeMdw.Names
  alias AeMdw.Validate

  require Ex2ms
  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @typep pubkey :: Db.pubkey()
  @typep cache_key ::
           String.t()
           | {Blocks.height(), pubkey()}
           | {pubkey(), String.t()}
           | pubkey()
           | {String.t(), <<>>, <<>>, <<>>, <<>>}
  @typep state() :: State.t()
  @typep table ::
           Model.ActiveName
           | Model.InactiveName
           | Model.ActiveNameExpiration
           | Model.InactiveNameExpiration
           | Model.AuctionExpiration
           | Model.AuctionBid
           | Model.AuctionOwner
           | Model.PlainName
           | Model.ActiveNameOwner
           | Model.InactiveNameOwner
           | Model.Pointee
  @typep name_record() ::
           Model.name()
           | Model.expiration()
           | Model.plain_name()
           | Model.owner()
           | Model.pointee()
           | Model.auction_bid()

  @spec plain_name(binary()) :: {:ok, String.t()} | nil
  def plain_name(name_hash),
    do: map_one_nil(read(Model.PlainName, name_hash), &{:ok, Model.plain_name(&1, :value)})

  @spec plain_name!(binary()) :: String.t()
  def plain_name!(name_hash),
    do: Model.plain_name(read!(Model.PlainName, name_hash), :value)

  @spec ptr_resolve!(Blocks.block_index(), binary(), String.t()) :: binary()
  def ptr_resolve!(block_index, name_hash, key) do
    key
    |> :aens.resolve_hash(name_hash, ns_tree!(block_index))
    |> map_ok!(&Validate.id!/1)
  end

  @spec owned_by(owner_pk :: pubkey(), active? :: boolean()) :: %{
          :names => list(),
          optional(:top_bids) => list()
        }
  def owned_by(owner_pk, true) do
    %{
      names: collect_vals(Model.ActiveNameOwner, owner_pk),
      top_bids: collect_vals(Model.AuctionOwner, owner_pk)
    }
  end

  def owned_by(owner_pk, false) do
    %{
      names: collect_vals(Model.InactiveNameOwner, owner_pk)
    }
  end

  @spec expire_after(Blocks.height()) :: Blocks.height()
  def expire_after(auction_end) do
    auction_end + :aec_governance.name_claim_max_expiration(proto_vsn(auction_end))
  end

  @spec expire_name(state(), Blocks.height(), Names.plain_name()) :: state()
  def expire_name(state, height, plain_name) do
    Model.name(expire: expiration) =
      m_name = cache_through_read!(state, Model.ActiveName, plain_name)

    state
    |> deactivate_name(height, expiration, m_name)
    |> State.inc_stat(:names_expired)
  end

  @spec expire_auction(
          state(),
          Blocks.height(),
          Names.plain_name(),
          Names.auction_timeout()
        ) :: state()
  def expire_auction(state, height, plain_name, timeout) do
    Model.auction_bid(block_index_txi: {_block_index, txi}, owner: owner, bids: bids) =
      ok!(cache_through_read(Model.AuctionBid, plain_name))

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
    %{tx: winning_tx} = read_raw_tx!(txi)

    state
    |> cache_through_write(Model.ActiveName, m_name)
    |> cache_through_write(Model.ActiveNameOwner, m_owner)
    |> cache_through_write(Model.ActiveNameExpiration, m_name_exp)
    |> cache_through_delete(Model.AuctionExpiration, {height, plain_name})
    |> cache_through_delete(Model.AuctionOwner, {owner, plain_name})
    |> cache_through_delete(Model.AuctionBid, plain_name)
    |> cache_through_delete_inactive(previous)
    |> IntTransfer.fee({height, -1}, :lock_name, owner, txi, winning_tx.name_fee)
    |> State.inc_stat(:names_activated)
    |> State.inc_stat(:auctions_expired)
  end

  @doc """
  Returns a stream of Names.plain_name()
  """
  @spec list_inactivated_at(State.t(), Blocks.height()) :: Enumerable.t()
  def list_inactivated_at(state, height) do
    state
    |> Collection.stream(
      Model.InactiveNameExpiration,
      :forward,
      {{height, <<>>}, {height + 1, <<>>}},
      nil
    )
    |> Stream.map(fn {_height, plain_name} -> plain_name end)
  end

  @spec source(AeMdw.Db.Model.ActiveName | AeMdw.Db.Model.InactiveName, :expiration | :name) ::
          AeMdw.Db.Model.ActiveName
          | AeMdw.Db.Model.ActiveNameExpiration
          | AeMdw.Db.Model.InactiveName
          | AeMdw.Db.Model.InactiveNameExpiration
  def source(Model.ActiveName, :name), do: Model.ActiveName
  def source(Model.ActiveName, :expiration), do: Model.ActiveNameExpiration
  def source(Model.InactiveName, :name), do: Model.InactiveName
  def source(Model.InactiveName, :expiration), do: Model.InactiveNameExpiration

  @spec locate_bid(Names.plain_name()) :: {:ok, Model.auction_bid()} | nil
  def locate_bid(plain_name), do: ok_nil(cache_through_read(Model.AuctionBid, plain_name))

  @spec locate(String.t()) ::
          {Model.name(), Model.ActiveName | Model.InactiveName}
          | {Model.auction_bid(), Model.AuctionBid}
          | nil
  def locate(plain_name) do
    map_ok_nil(cache_through_read(Model.ActiveName, plain_name), &{&1, Model.ActiveName}) ||
      map_ok_nil(cache_through_read(Model.InactiveName, plain_name), &{&1, Model.InactiveName}) ||
      map_some(locate_bid(plain_name), &{&1, Model.AuctionBid})
  end

  @spec pointers(Model.name()) :: map()
  def pointers(Model.name(updates: [])), do: %{}

  def pointers(Model.name(index: plain_name, updates: [{_block_index, txi} | _rest_updates])) do
    Model.tx(id: tx_hash) = read_tx!(txi)
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

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
            name_hash == :aens_update_tx.name_hash(tx)
          end)
          |> :aens_update_tx.pointers()
      end

    pointers
    |> Stream.map(&pointer_kv_raw/1)
    |> Enum.into(%{})
  end

  @spec ownership(Model.name()) :: %{current: Format.aeser_id(), original: Format.aeser_id()}
  def ownership(Model.name(transfers: [], owner: owner)) do
    pubkey = :aeser_id.create(:account, owner)

    %{original: pubkey, current: pubkey}
  end

  def ownership(
        Model.name(
          index: plain_name,
          claims: [{_block_index, last_claim_txi} | _rest_claims],
          owner: owner
        )
      ) do
    Model.tx(id: tx_hash) = read_tx!(last_claim_txi)
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    orig_owner =
      case AE.Db.get_tx_data(tx_hash) do
        {_block_hash, :name_claim_tx, _signed_tx, tx_rec} ->
          :aens_claim_tx.account_id(tx_rec)

        {_block_hash, :contract_call_tx, _signed_tx, _tx_rec} ->
          last_claim_txi
          |> Contracts.fetch_int_contract_calls("AENS.claim")
          |> Stream.map(fn Model.int_contract_call(tx: aetx) ->
            {:name_claim_tx, tx} = :aetx.specialize_type(aetx)

            tx
          end)
          |> Enum.find(fn tx ->
            name_hash == :aens_transfer_tx.name_hash(tx)
          end)
          |> :aens_transfer_tx.account_id()
      end

    %{original: orig_owner, current: :aeser_id.create(:account, owner)}
  end

  @spec account_pointer_at(String.t(), AeMdw.Txs.txi()) ::
          {:error, :name_not_found | {:pointee_not_found, any, any}} | {:ok, any}
  def account_pointer_at(plain_name, time_reference_txi) do
    case locate(plain_name) do
      nil ->
        {:error, :name_not_found}

      {m_name, _module} ->
        pointee_at(m_name, time_reference_txi)
    end
  end

  @spec pointee_keys(any) :: list
  def pointee_keys(pk) do
    Model.Pointee
    |> Collection.stream({pk, nil, nil})
    |> Stream.take_while(fn
      {^pk, _bi_txi, _pointee} -> true
      _other_key -> false
    end)
    |> Enum.map(fn {^pk, {bi, txi}, pointee} -> {bi, txi, pointee} end)
  end

  @spec pointees(pubkey()) :: {map(), map()}
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

  @spec revoke_or_expire_height(Model.name()) :: Blocks.height()
  def revoke_or_expire_height(m_name) do
    revoke_or_expire_height(Model.name(m_name, :revoke), Model.name(m_name, :expire))
  end

  @spec cache_through_read(table(), cache_key()) :: {:ok, name_record()} | nil
  def cache_through_read(table, key) do
    case :ets.lookup(:name_sync_cache, {table, key}) do
      [{_, record}] ->
        {:ok, record}

      [] ->
        case Database.fetch(table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  @spec cache_through_read(state(), table(), cache_key()) :: {:ok, name_record()} | nil
  def cache_through_read(state, table, key) do
    case State.cache_get(state, :name_sync_cache, {table, key}) do
      {:ok, record} ->
        {:ok, record}

      :not_found ->
        case State.get(state, table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  @spec cache_through_read!(state(), table(), cache_key()) :: name_record() | nil
  def cache_through_read!(state, table, key) do
    ok_nil(cache_through_read(state, table, key)) ||
      raise("#{inspect(key)} not found in #{table}")
  end

  @spec cache_through_prev(table(), cache_key()) :: {:ok, cache_key()} | :not_found
  def cache_through_prev(table, key),
    do: cache_through_prev(table, key, &(elem(key, 0) == elem(&1, 0)))

  defp cache_through_prev(table, key, key_checker) do
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

    mns_lookup = fn ->
      case Database.prev_key(table, key) do
        {:ok, prev_key} -> lookup.(prev_key, & &1, nf, nf)
        :none -> :not_found
      end
    end

    lookup.(:ets.prev(:name_sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  @spec cache_through_write(state(), table(), name_record()) :: state()
  def cache_through_write(state, table, record) do
    state
    |> State.cache_put(:name_sync_cache, {table, elem(record, 1)}, record)
    |> State.put(table, record)
  end

  @spec cache_through_delete(state(), table(), cache_key()) :: state()
  def cache_through_delete(state, table, key) do
    state
    |> State.cache_delete(:name_sync_cache, {table, key})
    |> State.delete(table, key)
  end

  @spec cache_through_delete_inactive(State.t(), nil | Model.name()) :: State.t()
  def cache_through_delete_inactive(state, nil), do: state

  def cache_through_delete_inactive(
        state,
        Model.name(index: plain_name, owner: owner_pk) = m_name
      ) do
    expire = revoke_or_expire_height(m_name)

    state
    |> cache_through_delete(Model.InactiveName, plain_name)
    |> cache_through_delete(Model.InactiveNameOwner, {owner_pk, plain_name})
    |> cache_through_delete(Model.InactiveNameExpiration, {expire, plain_name})
  end

  @spec deactivate_name(State.t(), Blocks.height(), Blocks.height(), Model.name()) :: State.t()
  def deactivate_name(
        state,
        deactivate_height,
        expiration,
        Model.name(index: plain_name, owner: owner_pk) = m_name
      ) do
    m_exp = Model.expiration(index: {deactivate_height, plain_name})
    m_owner = Model.owner(index: {owner_pk, plain_name})

    state
    |> cache_through_delete_active(expiration, m_name)
    |> cache_through_write(Model.InactiveName, m_name)
    |> cache_through_write(Model.InactiveNameExpiration, m_exp)
    |> cache_through_write(Model.InactiveNameOwner, m_owner)
  end

  #
  # Private functions
  #
  defp revoke_or_expire_height(nil = _revoke, expire), do: expire
  defp revoke_or_expire_height({{revoke_height, _}, _}, _expire), do: revoke_height

  defp cache_through_delete_active(
         state,
         expiration,
         Model.name(index: plain_name, owner: owner_pk)
       ) do
    state
    |> cache_through_delete(Model.ActiveName, plain_name)
    |> cache_through_delete(Model.ActiveNameOwner, {owner_pk, plain_name})
    |> cache_through_delete(Model.ActiveNameExpiration, {expiration, plain_name})
  end

  defp pointer_kv_raw(ptr),
    do: {:aens_pointer.key(ptr), :aens_pointer.id(ptr)}

  defp collect_vals(tab, key) do
    collect_keys(tab, [], {key, ""}, &next/2, fn
      {^key, val}, acc -> {:cont, [val | acc]}
      {_, _}, acc -> {:halt, acc}
    end)
  end

  defp ns_tree!({_, _} = block_index) do
    block_index
    |> read_block!
    |> Model.block(:hash)
    |> :aec_db.get_block_state()
    |> :aec_trees.ns()
  end

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

  defp read_raw_tx!(txi),
    do: Format.to_raw_map(read_tx!(txi))
end
