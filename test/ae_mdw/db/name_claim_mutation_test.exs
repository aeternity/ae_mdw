defmodule AeMdw.Db.NameClaimMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync

  import Mock

  require Model

  test "claim an inactive name with timeout 0" do
    plain_name = "claim.test"

    new_owner_pk =
      <<11, 180, 237, 121, 39, 249, 123, 81, 225, 188, 181, 225, 52, 13, 18, 51, 91, 42, 43, 18,
        200, 188, 82, 33, 214, 60, 75, 203, 57, 212, 30, 97>>

    tx =
      {:ns_claim_tx, {:id, :account, new_owner_pk}, 11_251, plain_name, 7, :prelima,
       1_000_000_000_000_000, 0}

    tx_hash =
      <<159, 240, 103, 205, 63, 165, 186, 153, 226, 186, 128, 241, 61, 192, 66, 89, 156, 217, 200,
        247, 31, 137, 16, 129, 250, 190, 199, 100, 137, 179, 112, 165>>

    claim_height = 200
    old_claim_height = 100
    old_claims = [{{old_claim_height, 1}, 123}]
    owner_pk = <<8435::256>>
    block_index = {claim_height, 0}
    txi = 223
    txi_idx = {txi, -1}

    inactive_name =
      Model.name(
        index: plain_name,
        active: old_claim_height,
        expire: 199,
        claims: old_claims,
        updates: [{{150, 0}, {173, -1}}],
        owner: owner_pk,
        previous: nil
      )

    Database.dirty_write(Model.InactiveName, inactive_name)

    Database.dirty_write(
      Model.InactiveNameExpiration,
      Model.expiration(index: {199, plain_name})
    )

    Database.dirty_write(
      Model.InactiveNameOwner,
      Model.owner(index: {owner_pk, plain_name})
    )

    state = State.new()

    with_mocks [
      {AeMdw.Node.Db, [], [proto_vsn: fn _height -> 3 end]}
    ] do
      mutations = Sync.Name.name_claim_mutations(tx, tx_hash, block_index, txi_idx)

      State.commit(state, mutations)
    end

    assert {:ok,
            Model.name(
              index: ^plain_name,
              active: ^claim_height,
              claims: [{^block_index, ^txi_idx} | _old_claims],
              expire: expire,
              owner: ^new_owner_pk,
              updates: []
            )} = State.get(state, Model.ActiveName, plain_name)

    assert State.exists?(state, Model.ActiveNameActivation, {claim_height, plain_name})
    assert State.exists?(state, Model.ActiveNameExpiration, {expire, plain_name})
    assert State.exists?(state, Model.ActiveNameOwner, {new_owner_pk, plain_name})

    assert State.exists?(
             state,
             Model.ActiveNameOwnerDeactivation,
             {new_owner_pk, expire, plain_name}
           )
  end

  test "claim new name with timeout > 0" do
    plain_name = "claim_new.test"
    name_hash = :crypto.strong_rand_bytes(32)
    owner_pk = :crypto.strong_rand_bytes(32)
    name_fee = 1_000_000_000_000
    claim_height = 23
    block_index = {claim_height, 0}
    timeout = 54
    txi = 1234
    txi_idx = {txi, -1}
    state = State.new()

    State.commit(state, [
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        false,
        txi_idx,
        block_index,
        timeout
      )
    ])

    refute State.exists?(state, Model.ActiveName, plain_name)
    refute State.exists?(state, Model.ActiveNameActivation, {claim_height, plain_name})
    refute State.exists?(state, Model.ActiveNameOwner, {owner_pk, plain_name})

    refute State.exists?(
             state,
             Model.ActiveNameOwnerDeactivation,
             {owner_pk, claim_height + timeout, plain_name}
           )

    assert {:ok,
            Model.auction_bid(
              index: ^plain_name,
              owner: ^owner_pk,
              bids: [{^block_index, ^txi_idx}]
            )} = State.get(state, Model.AuctionBid, plain_name)

    assert State.exists?(state, Model.AuctionOwner, {owner_pk, plain_name})
    assert State.exists?(state, Model.AuctionExpiration, {claim_height + timeout, plain_name})
  end
end
