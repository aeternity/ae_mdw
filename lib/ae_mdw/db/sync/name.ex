defmodule AeMdw.Db.Sync.Name do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Names
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @type update_type() :: {:update_expiration, Blocks.height()} | :expire | :update

  @typep pubkey :: Db.pubkey()
  @typep state() :: State.t()
  @typep table ::
           Model.ActiveName
           | Model.InactiveName
           | Model.ActiveNameActivation
           | Model.ActiveNameExpiration
           | Model.InactiveNameExpiration
           | Model.ActiveNameOwnerDeactivation
           | Model.InactiveNameOwnerDeactivation
           | Model.AuctionExpiration
           | Model.AuctionBid
           | Model.AuctionOwner
           | Model.PlainName
           | Model.ActiveNameOwner
           | Model.InactiveNameOwner
           | Model.Pointee
  @typep name_record() ::
           Model.name()
           | Model.activation()
           | Model.expiration()
           | Model.plain_name()
           | Model.owner()
           | Model.pointee()
           | Model.auction_bid()
           | Model.owner_deactivation()
  @typep cache_key ::
           String.t()
           | {Blocks.height(), pubkey()}
           | {pubkey(), String.t()}
           | pubkey()
           | {String.t(), <<>>, <<>>, <<>>, <<>>}
           | {pubkey(), Blocks.height(), binary()}

  @spec name_claim_mutations(Node.tx(), Txs.tx_hash(), Blocks.block_index(), Txs.txi_idx()) :: [
          Mutation.t()
        ]
  def name_claim_mutations(tx, tx_hash, {height, _mbi} = block_index, {txi, _idx} = txi_idx) do
    plain_name = String.downcase(:aens_claim_tx.name(tx))
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    owner_pk = Validate.id!(:aens_claim_tx.account_id(tx))
    name_fee = :aens_claim_tx.name_fee(tx)
    proto_vsn = Db.proto_vsn(height)
    lima_or_higher? = height >= Node.lima_height()
    timeout = :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)

    [
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        lima_or_higher?,
        txi_idx,
        block_index,
        timeout
      )
      | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
    ]
  end

  @spec update_mutations(Node.tx(), Txs.txi_idx(), Blocks.block_index(), boolean()) :: [
          Mutation.t()
        ]
  def update_mutations(tx, txi_idx, {height, _mbi} = block_index, internal? \\ false) do
    name_hash = :aens_update_tx.name_hash(tx)
    pointers = :aens_update_tx.pointers(tx)
    name_ttl = :aens_update_tx.name_ttl(tx)

    update_type =
      cond do
        # name_ttl from the name transaction depends on whether it is a name_update transaction or
        # a AENS.update call (internal?)
        name_ttl > 0 and internal? ->
          {:update_expiration, name_ttl}

        name_ttl > 0 and not internal? ->
          {:update_expiration, height + name_ttl}

        name_ttl == 0 and internal? ->
          :update

        name_ttl == 0 and not internal? ->
          :expire
      end

    [
      NameUpdateMutation.new(name_hash, update_type, pointers, txi_idx, block_index)
    ]
  end

  @spec update(
          state(),
          Names.name_hash(),
          update_type(),
          Names.pointers(),
          Txs.txi_idx(),
          Blocks.block_index()
        ) :: State.t()
  def update(state, name_hash, update_type, pointers, txi_idx, {height, _mbi} = bi) do
    plain_name = plain_name!(state, name_hash)

    Model.name(active: active, expire: old_expire, owner: owner_pk) =
      m_name = cache_through_read!(state, Model.ActiveName, plain_name)

    state2 =
      pointers
      |> Enum.reduce(state, fn ptr, state ->
        m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi_idx}))

        cache_through_write(state, Model.Pointee, m_pointee)
      end)
      |> State.put(Model.NameUpdate, Model.name_update(index: {plain_name, active, txi_idx}))

    case update_type do
      {:update_expiration, new_expire} ->
        new_m_name = Model.name(m_name, expire: new_expire)
        new_m_name_exp = Model.expiration(index: {new_expire, plain_name})

        m_name_owner_deactivation =
          Model.owner_deactivation(index: {owner_pk, new_expire, plain_name})

        state2
        |> cache_through_delete(Model.ActiveNameExpiration, {old_expire, plain_name})
        |> cache_through_delete(
          Model.ActiveNameOwnerDeactivation,
          {owner_pk, old_expire, plain_name}
        )
        |> cache_through_write(Model.ActiveNameExpiration, new_m_name_exp)
        |> cache_through_write(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
        |> cache_through_write(Model.ActiveName, new_m_name)

      :expire ->
        new_m_name = Model.name(m_name, expire: height)

        state2
        |> deactivate_name(height, old_expire, new_m_name)
        |> State.inc_stat(:names_expired)

      :update ->
        state
    end
  end

  @spec transfer(State.t(), Names.name_hash(), Db.pubkey(), Txs.txi_idx(), Blocks.block_index()) ::
          State.t()
  def transfer(state, name_hash, new_owner, txi_idx, block_index) do
    plain_name = plain_name!(state, name_hash)

    m_name = cache_through_read!(state, Model.ActiveName, plain_name)
    Model.name(active: active, owner: old_owner, expire: expire) = m_name

    m_name = Model.name(m_name, active: active, owner: new_owner)
    m_owner = Model.owner(index: {new_owner, plain_name})
    m_name_owner_deactivation = Model.owner_deactivation(index: {new_owner, expire, plain_name})
    name_transfer = Model.name_transfer(index: {plain_name, active, {block_index, txi_idx}})

    state
    |> cache_through_delete(Model.ActiveNameOwner, {old_owner, plain_name})
    |> cache_through_delete(Model.ActiveNameOwnerDeactivation, {old_owner, expire, plain_name})
    |> cache_through_write(Model.ActiveNameOwner, m_owner)
    |> cache_through_write(Model.ActiveName, m_name)
    |> cache_through_write(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
    |> State.put(Model.NameTransfer, name_transfer)
  end

  @spec revoke(State.t(), Names.name_hash(), Txs.txi_idx(), Blocks.block_index()) :: State.t()
  def revoke(state, name_hash, txi_idx, {height, _mbi} = bi) do
    plain_name = plain_name!(state, name_hash)

    Model.name(expire: expiration) =
      m_name = cache_through_read!(state, Model.ActiveName, plain_name)

    m_name = Model.name(m_name, revoke: {bi, txi_idx})

    state
    |> deactivate_name(height, expiration, m_name)
    |> State.inc_stat(:names_revoked)
  end

  @spec expire_name(state(), Blocks.height(), Names.plain_name()) :: state()
  def expire_name(state, height, plain_name) do
    Model.name(expire: expiration) =
      m_name = cache_through_read!(state, Model.ActiveName, plain_name)

    state
    |> deactivate_name(height, expiration, m_name)
    |> State.inc_stat(:names_expired)
  end

  @spec expire_auction(state(), Blocks.height(), Names.plain_name()) :: state()
  def expire_auction(state, height, plain_name) do
    {:ok,
     Model.auction_bid(
       block_index_txi_idx: {{last_bid_height, _mbi} = _block_index, txi_idx},
       owner: owner
     )} = cache_through_read(state, Model.AuctionBid, plain_name)

    previous =
      case cache_through_read(state, Model.InactiveName, plain_name) do
        {:ok, inactive_name} -> inactive_name
        _not_found_or_nil -> nil
      end

    expire = Names.expire_after(height)

    m_name =
      Model.name(
        index: plain_name,
        active: height,
        expire: expire,
        auction_timeout: height - last_bid_height,
        owner: owner,
        previous: previous
      )

    m_name_activation = Model.activation(index: {height, plain_name})
    m_name_exp = Model.expiration(index: {expire, plain_name})
    m_owner = Model.owner(index: {owner, plain_name})
    m_name_owner_deactivation = Model.owner_deactivation(index: {owner, expire, plain_name})

    name_fee =
      state
      |> DbUtil.read_node_tx(txi_idx)
      |> :aens_claim_tx.name_fee()

    state
    |> Collection.stream(Model.AuctionBidClaim, {plain_name, height, nil})
    |> Stream.take_while(&match?({^plain_name, ^height, _txi_idx}, &1))
    |> Enum.reduce(state, fn {^plain_name, ^height, claim_txi_idx}, state ->
      state
      |> State.put(Model.NameClaim, Model.name_claim(index: {plain_name, height, claim_txi_idx}))
      |> State.delete(Model.AuctionBidClaim, {plain_name, height, claim_txi_idx})
    end)
    |> cache_through_write(Model.ActiveName, m_name)
    |> cache_through_write(Model.ActiveNameOwner, m_owner)
    |> cache_through_write(Model.ActiveNameActivation, m_name_activation)
    |> cache_through_write(Model.ActiveNameExpiration, m_name_exp)
    |> cache_through_write(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
    |> cache_through_delete(Model.AuctionExpiration, {height, plain_name})
    |> cache_through_delete(Model.AuctionOwner, {owner, plain_name})
    |> cache_through_delete(Model.AuctionBid, plain_name)
    |> cache_through_delete_inactive(previous)
    |> IntTransfer.fee({height, -1}, :lock_name, owner, txi_idx, name_fee)
    |> State.inc_stat(:names_activated)
    |> State.inc_stat(:auctions_expired)
    |> State.inc_stat(:burned_in_auctions, name_fee)
    |> State.inc_stat(:locked_in_auctions, -name_fee)
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

  defp cache_through_delete_active(
         state,
         expiration,
         Model.name(index: plain_name, active: active_from, owner: owner_pk)
       ) do
    state
    |> cache_through_delete(Model.ActiveName, plain_name)
    |> cache_through_delete(Model.ActiveNameOwner, {owner_pk, plain_name})
    |> cache_through_delete(Model.ActiveNameActivation, {active_from, plain_name})
    |> cache_through_delete(Model.ActiveNameExpiration, {expiration, plain_name})
    |> cache_through_delete(Model.ActiveNameOwnerDeactivation, {owner_pk, expiration, plain_name})
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

  @spec cache_through_read!(state(), table(), cache_key()) :: name_record()
  def cache_through_read!(state, table, key) do
    case cache_through_read(state, table, key) do
      {:ok, record} -> record
      nil -> raise("#{inspect(key)} not found in #{table}")
    end
  end

  @spec deactivate_name(state(), Blocks.height(), Blocks.height(), Model.name()) :: state()
  def deactivate_name(
        state,
        deactivate_height,
        expiration,
        Model.name(index: plain_name, owner: owner_pk) = m_name
      ) do
    m_exp = Model.expiration(index: {deactivate_height, plain_name})
    m_owner = Model.owner(index: {owner_pk, plain_name})

    m_owner_deactivation =
      Model.owner_deactivation(index: {owner_pk, deactivate_height, plain_name})

    state
    |> cache_through_delete_active(expiration, m_name)
    |> cache_through_write(Model.InactiveName, m_name)
    |> cache_through_write(Model.InactiveNameExpiration, m_exp)
    |> cache_through_write(Model.InactiveNameOwner, m_owner)
    |> cache_through_write(Model.InactiveNameOwnerDeactivation, m_owner_deactivation)
  end

  @spec cache_through_delete_inactive(state(), nil | Model.name()) :: state()
  def cache_through_delete_inactive(state, nil), do: state

  def cache_through_delete_inactive(
        state,
        Model.name(index: plain_name, owner: owner_pk) = m_name
      ) do
    expire = Names.revoke_or_expire_height(m_name)

    state
    |> cache_through_delete(Model.InactiveName, plain_name)
    |> cache_through_delete(Model.InactiveNameOwner, {owner_pk, plain_name})
    |> cache_through_delete(Model.InactiveNameExpiration, {expire, plain_name})
    |> cache_through_delete(Model.InactiveNameOwnerDeactivation, {owner_pk, expire, plain_name})
  end

  defp plain_name!(state, name_hash) do
    {:ok, m_plain_name} = cache_through_read(state, Model.PlainName, name_hash)

    Model.plain_name(m_plain_name, :value)
  end

  defp pointee_key(ptr, {bi, txi_idx}) do
    {k, v} = pointer_kv(ptr)
    {v, {bi, txi_idx}, k}
  end

  defp pointer_kv(ptr) do
    {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}
  end
end
