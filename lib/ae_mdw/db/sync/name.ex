defmodule AeMdw.Db.Sync.Name do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
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

  @typep plain_name() :: Names.plain_name()
  @typep state :: State.t()
  @typep deactivate_stat :: :names_expired | :names_revoked

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
    plain_name = Name.plain_name!(state, name_hash)

    Model.name(active: active, expire: old_expire, owner: owner_pk) =
      m_name = State.fetch!(state, Model.ActiveName, plain_name)

    state2 =
      pointers
      |> Enum.reduce(state, fn ptr, state ->
        m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi_idx}))

        State.put(state, Model.Pointee, m_pointee)
      end)
      |> State.put(Model.NameUpdate, Model.name_update(index: {plain_name, active, txi_idx}))

    case update_type do
      {:update_expiration, new_expire} ->
        new_m_name = Model.name(m_name, expire: new_expire)
        new_m_name_exp = Model.expiration(index: {new_expire, plain_name})

        m_name_owner_deactivation =
          Model.owner_deactivation(index: {owner_pk, new_expire, plain_name})

        state2
        |> State.delete(Model.ActiveNameExpiration, {old_expire, plain_name})
        |> State.delete(
          Model.ActiveNameOwnerDeactivation,
          {owner_pk, old_expire, plain_name}
        )
        |> State.put(Model.ActiveNameExpiration, new_m_name_exp)
        |> State.put(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
        |> State.put(Model.ActiveName, new_m_name)

      :expire ->
        new_m_name = Model.name(m_name, expire: height)
        deactivate_name(state2, height, old_expire, new_m_name, :names_expired)

      :update ->
        state
    end
  end

  @spec transfer(State.t(), Names.name_hash(), Db.pubkey(), Txs.txi_idx()) ::
          State.t()
  def transfer(state, name_hash, new_owner, txi_idx) do
    plain_name = Name.plain_name!(state, name_hash)

    m_name = State.fetch!(state, Model.ActiveName, plain_name)
    Model.name(active: active, owner: old_owner, expire: expire) = m_name

    m_name = Model.name(m_name, active: active, owner: new_owner)
    m_owner = Model.owner(index: {new_owner, plain_name})
    m_name_owner_deactivation = Model.owner_deactivation(index: {new_owner, expire, plain_name})
    name_transfer = Model.name_transfer(index: {plain_name, active, txi_idx})

    state
    |> State.put(Model.NameTransfer, name_transfer)
    |> State.delete(Model.ActiveNameOwner, {old_owner, plain_name})
    |> State.delete(Model.ActiveNameOwnerDeactivation, {old_owner, expire, plain_name})
    |> State.put(Model.ActiveNameOwner, m_owner)
    |> State.put(Model.ActiveName, m_name)
    |> State.put(Model.ActiveNameOwnerDeactivation, m_name_owner_deactivation)
  end

  @spec revoke(State.t(), Names.plain_name(), Txs.txi_idx(), Blocks.block_index()) :: State.t()
  def revoke(state, plain_name, txi_idx, {height, _mbi} = bi) do
    Model.name(active: active_height, expire: expiration) =
      m_name = State.fetch!(state, Model.ActiveName, plain_name)

    m_name = Model.name(m_name, revoke: {bi, txi_idx})
    m_revoke = Model.name_revoke(index: {plain_name, active_height, txi_idx})

    state
    |> State.put(Model.NameRevoke, m_revoke)
    |> deactivate_name(height, expiration, m_name, :names_revoked)
  end

  @spec expire_name(state(), Blocks.height(), Names.plain_name()) :: state()
  def expire_name(state, height, plain_name) do
    Model.name(active: active, expire: expiration) =
      m_name = State.fetch!(state, Model.ActiveName, plain_name)

    state
    |> State.put(
      Model.NameExpired,
      Model.name_expired(index: {plain_name, active, {nil, height}})
    )
    |> deactivate_name(height, expiration, m_name, :names_expired)
  end

  @spec expire_auction(state(), Blocks.height(), Names.plain_name()) :: state()
  def expire_auction(state, height, plain_name) do
    Model.auction_bid(
      block_index_txi_idx: {{last_bid_height, _mbi} = _block_index, txi_idx},
      owner: owner
    ) = State.fetch!(state, Model.AuctionBid, plain_name)

    expire = Names.expire_after(height)

    m_name =
      Model.name(
        index: plain_name,
        active: height,
        expire: expire,
        auction_timeout: height - last_bid_height,
        owner: owner
      )

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
    |> put_active(m_name)
    |> State.delete(Model.AuctionExpiration, {height, plain_name})
    |> State.delete(Model.AuctionOwner, {owner, plain_name})
    |> State.delete(Model.AuctionBid, plain_name)
    |> delete_inactive(plain_name)
    |> IntTransfer.fee({height, -1}, :lock_name, owner, txi_idx, name_fee)
    |> State.inc_stat(:auctions_expired)
    |> State.inc_stat(:burned_in_auctions, name_fee)
    |> State.inc_stat(:locked_in_auctions, -name_fee)
  end

  @spec put_active(state(), Model.name()) :: state()
  def put_active(
        state,
        Model.name(index: plain_name, active: height, expire: expire, owner: owner_pk) = m_name
      ) do
    m_owner = Model.owner(index: {owner_pk, plain_name})
    m_activation = Model.activation(index: {height, plain_name})
    m_expiration = Model.expiration(index: {expire, plain_name})
    m_owner_deactivation = Model.owner_deactivation(index: {owner_pk, expire, plain_name})

    state
    |> State.put(Model.ActiveName, m_name)
    |> State.put(Model.ActiveNameOwner, m_owner)
    |> State.put(Model.ActiveNameActivation, m_activation)
    |> State.put(Model.ActiveNameExpiration, m_expiration)
    |> State.put(Model.ActiveNameOwnerDeactivation, m_owner_deactivation)
    |> State.inc_stat(:names_activated)
  end

  @spec deactivate_name(
          state(),
          Blocks.height(),
          Blocks.height(),
          Model.name(),
          deactivate_stat()
        ) :: state()
  def deactivate_name(
        state,
        deactivate_height,
        expiration,
        Model.name(index: plain_name, owner: owner_pk) = m_name,
        reason
      ) do
    m_exp = Model.expiration(index: {deactivate_height, plain_name})
    m_owner = Model.owner(index: {owner_pk, plain_name})

    m_owner_deactivation =
      Model.owner_deactivation(index: {owner_pk, deactivate_height, plain_name})

    state
    |> delete_active(expiration, m_name)
    |> State.put(Model.InactiveName, m_name)
    |> State.put(Model.InactiveNameExpiration, m_exp)
    |> State.put(Model.InactiveNameOwner, m_owner)
    |> State.put(Model.InactiveNameOwnerDeactivation, m_owner_deactivation)
    |> State.inc_stat(reason)
  end

  @spec delete_inactive(state(), plain_name()) :: state()
  def delete_inactive(state, plain_name) do
    case State.get(state, Model.InactiveName, plain_name) do
      {:ok, Model.name(active: active, owner: owner_pk) = name} ->
        expire = Names.revoke_or_expire_height(name)
        prev_name = Model.previous_name(index: {plain_name, active}, name: name)

        state
        |> State.delete(Model.InactiveName, plain_name)
        |> State.delete(Model.InactiveNameOwner, {owner_pk, plain_name})
        |> State.delete(Model.InactiveNameExpiration, {expire, plain_name})
        |> State.delete(Model.InactiveNameOwnerDeactivation, {owner_pk, expire, plain_name})
        |> State.put(Model.PreviousName, prev_name)

      :not_found ->
        state
    end
  end

  defp delete_active(
         state,
         expiration,
         Model.name(index: plain_name, active: active_from, owner: owner_pk)
       ) do
    state
    |> State.delete(Model.ActiveName, plain_name)
    |> State.delete(Model.ActiveNameOwner, {owner_pk, plain_name})
    |> State.delete(Model.ActiveNameActivation, {active_from, plain_name})
    |> State.delete(Model.ActiveNameExpiration, {expiration, plain_name})
    |> State.delete(Model.ActiveNameOwnerDeactivation, {owner_pk, expiration, plain_name})
  end

  defp pointee_key(ptr, {bi, txi_idx}) do
    {k, v} = pointer_kv(ptr)
    {v, {bi, txi_idx}, k}
  end

  defp pointer_kv(ptr) do
    {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}
  end
end
