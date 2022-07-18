defmodule AeMdw.Db.Sync.Name do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
  alias AeMdw.Names
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Log
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @spec name_claim_mutations(Node.tx(), Txs.tx_hash(), Blocks.block_index(), Txs.txi()) :: [
          Mutation.t()
        ]
  def name_claim_mutations(tx, tx_hash, {height, _mbi} = block_index, txi) do
    plain_name = String.downcase(:aens_claim_tx.name(tx))
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    owner_pk = Validate.id!(:aens_claim_tx.account_id(tx))
    name_fee = :aens_claim_tx.name_fee(tx)
    proto_vsn = Db.proto_vsn(height)
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

  @spec update(
          State.t(),
          Names.name_hash(),
          Names.ttl(),
          Names.pointers(),
          Txs.txi(),
          Blocks.block_index(),
          boolean()
        ) :: State.t()
  def update(state, name_hash, delta_ttl, pointers, txi, {height, _mbi} = bi, internal?) do
    plain_name = plain_name!(state, name_hash)
    m_name = Name.cache_through_read!(state, Model.ActiveName, plain_name)
    old_expire = Model.name(m_name, :expire)
    new_expire = height + delta_ttl
    updates = [{bi, txi} | Model.name(m_name, :updates)]
    new_m_name_exp = Model.expiration(index: {new_expire, plain_name})
    new_m_name = Model.name(m_name, expire: new_expire, updates: updates)

    state2 =
      Enum.reduce(pointers, state, fn ptr, state ->
        m_pointee = Model.pointee(index: pointee_key(ptr, {bi, txi}))

        Name.cache_through_write(state, Model.Pointee, m_pointee)
      end)

    cond do
      delta_ttl > 0 ->
        log_name_change(height, plain_name, "extend")

        state2
        |> Name.cache_through_delete(Model.ActiveNameExpiration, {old_expire, plain_name})
        |> Name.cache_through_write(Model.ActiveNameExpiration, new_m_name_exp)
        |> Name.cache_through_write(Model.ActiveName, new_m_name)

      delta_ttl == 0 and not internal? ->
        log_name_change(height, plain_name, "expire")

        state2
        |> Name.deactivate_name(height, old_expire, new_m_name)
        |> State.inc_stat(:names_expired)

      true ->
        log_name_change(height, plain_name, "delta_ttl #{delta_ttl} NA")

        if internal? do
          m_name = Model.name(m_name, updates: updates)
          Name.cache_through_write(state2, Model.ActiveName, m_name)
        else
          state2
        end
    end
  end

  @spec transfer(State.t(), Names.name_hash(), Db.pubkey(), Txs.txi(), Blocks.block_index()) ::
          State.t()
  def transfer(state, name_hash, new_owner, txi, {height, _mbi} = bi) do
    plain_name = plain_name!(state, name_hash)

    m_name = Name.cache_through_read!(state, Model.ActiveName, plain_name)
    old_owner = Model.name(m_name, :owner)

    transfers = [{bi, txi} | Model.name(m_name, :transfers)]
    m_name = Model.name(m_name, transfers: transfers, owner: new_owner)
    m_owner = Model.owner(index: {new_owner, plain_name})

    log_name_change(height, plain_name, "transfer")

    state
    |> Name.cache_through_delete(Model.ActiveNameOwner, {old_owner, plain_name})
    |> Name.cache_through_write(Model.ActiveNameOwner, m_owner)
    |> Name.cache_through_write(Model.ActiveName, m_name)
  end

  @spec revoke(State.t(), Names.name_hash(), Txs.txi(), Blocks.block_index()) :: State.t()
  def revoke(state, name_hash, txi, {height, _mbi} = bi) do
    plain_name = plain_name!(state, name_hash)

    Model.name(expire: expiration) =
      m_name = Name.cache_through_read!(state, Model.ActiveName, plain_name)

    m_name = Model.name(m_name, revoke: {bi, txi})

    log_name_change(height, plain_name, "revoke")

    state
    |> Name.deactivate_name(height, expiration, m_name)
    |> State.inc_stat(:names_revoked)
  end

  defp plain_name!(state, name_hash) do
    {:ok, m_plain_name} = Name.cache_through_read(state, Model.PlainName, name_hash)

    Model.plain_name(m_plain_name, :value)
  end

  defp log_name_change(height, plain_name, change),
    do: Log.info("[#{height}][name] #{change} #{plain_name}")

  defp pointee_key(ptr, {bi, txi}) do
    {k, v} = pointer_kv(ptr)
    {v, {bi, txi}, k}
  end

  defp pointer_kv(ptr) do
    {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}
  end
end
