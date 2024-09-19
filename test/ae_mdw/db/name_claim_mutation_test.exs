defmodule AeMdw.Db.NameClaimMutationTest do
  use AeMdw.Db.MutationCase
  import Mock

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync

  require Model

  test "claim an inactive name with timeout 0", %{store: store} do
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
    owner_pk = <<8435::256>>
    block_index = {claim_height, 0}
    txi = 223
    txi_idx = {txi, -1}

    inactive_name =
      Model.name(
        index: plain_name,
        active: old_claim_height,
        expire: 199,
        owner: owner_pk,
        claims_count: 3
      )

    state =
      store
      |> Store.put(Model.InactiveName, inactive_name)
      |> Store.put(Model.InactiveNameExpiration, Model.expiration(index: {199, plain_name}))
      |> Store.put(Model.InactiveNameOwner, Model.owner(index: {owner_pk, plain_name}))
      |> Store.put(
        Model.InactiveNameOwnerDeactivation,
        Model.owner(index: {owner_pk, 199, plain_name})
      )
      |> State.new()

    with_mocks [
      {AeMdw.Node.Db, [], [proto_vsn: fn _height -> 3 end]}
    ] do
      mutations = Sync.Name.name_claim_mutations(tx, tx_hash, block_index, txi_idx)

      state =
        mutations
        |> Enum.reduce(state, fn mutation, state -> Mutation.execute(mutation, state) end)

      assert {:ok,
              Model.name(
                index: ^plain_name,
                active: ^claim_height,
                expire: expire,
                owner: ^new_owner_pk,
                claims_count: 1
              )} = State.get(state, Model.ActiveName, plain_name)

      assert State.exists?(state, Model.ActiveNameActivation, {claim_height, plain_name})
      assert State.exists?(state, Model.ActiveNameExpiration, {expire, plain_name})
      assert State.exists?(state, Model.ActiveNameOwner, {new_owner_pk, plain_name})

      assert State.exists?(state, Model.NameClaim, {plain_name, claim_height, txi_idx})
      refute State.exists?(state, Model.NameUpdate, {plain_name, claim_height, txi_idx})

      assert State.exists?(
               state,
               Model.ActiveNameOwnerDeactivation,
               {new_owner_pk, expire, plain_name}
             )
    end
  end

  test "claim new name with timeout > 0", %{store: store} do
    plain_name = "claimnew.test"
    name_hash = :crypto.strong_rand_bytes(32)
    owner_pk = :crypto.strong_rand_bytes(32)
    name_fee = 1_000_000_000_000
    protocol_version = 6
    txi = 1234
    txi_idx = {txi, -1}
    state = State.new(store)

    claim_height = 23
    block_index = {claim_height, 0}
    timeout = :aec_governance.name_claim_bid_timeout(plain_name, protocol_version)

    mutation =
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        false,
        txi_idx,
        block_index,
        protocol_version
      )

    state = Mutation.execute(mutation, state)

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
              start_height: ^claim_height,
              owner: ^owner_pk,
              claims_count: 1
            )} = State.get(state, Model.AuctionBid, plain_name)

    assert State.exists?(state, Model.AuctionOwner, {owner_pk, plain_name})
    assert State.exists?(state, Model.AuctionExpiration, {claim_height + timeout, plain_name})
    assert State.exists?(state, Model.AuctionBidClaim, {plain_name, claim_height, txi_idx})
  end

  test "place bid on name", %{store: store} do
    plain_name = "bid.test"
    name_hash = :crypto.strong_rand_bytes(32)
    owner_pk = :crypto.strong_rand_bytes(32)
    name_fee = 1_000_000_000_000
    protocol_version = 6
    txi = 1234
    txi_idx = {txi, -1}
    claim_height = 23
    block_index = {claim_height, 0}
    state = State.new(store)
    timeout = :aec_governance.name_claim_bid_timeout(plain_name, protocol_version)
    extension = :aec_governance.name_claim_bid_extension(plain_name, protocol_version)
    tx_hash = <<1::256>>
    expire_height = claim_height + timeout

    mutation =
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        false,
        txi_idx,
        block_index,
        protocol_version
      )

    state =
      State.put(state, Model.Tx, Model.tx(index: txi, id: tx_hash))

    state =
      Mutation.execute(mutation, state)

    assert {:ok,
            Model.auction_bid(
              index: ^plain_name,
              start_height: ^claim_height,
              owner: ^owner_pk,
              expire_height: ^expire_height,
              claims_count: 1
            )} = State.get(state, Model.AuctionBid, plain_name)

    next_txi = txi + 1
    next_txi_idx = {next_txi, -1}
    state = State.put(state, Model.Tx, Model.tx(index: next_txi, id: <<2::256>>))

    bid_mutation =
      NameClaimMutation.new(
        plain_name,
        name_hash,
        owner_pk,
        name_fee,
        false,
        next_txi_idx,
        {claim_height, 0},
        protocol_version
      )

    {:ok, claim_aetx} =
      :aens_claim_tx.new(%{
        account_id: :aeser_id.create(:account, <<0::256>>),
        nonce: 1,
        name: plain_name,
        name_salt: 0,
        name_fee: name_fee,
        fee: 5_000
      })

    {:name_claim_tx, claim_tx} = :aetx.specialize_type(claim_aetx)

    with_mocks [
      {AeMdw.Node.Db, [:passthrough],
       [get_tx_data: fn _tx_hash -> {<<456::256>>, :name_claim_tx, :signed_tx, claim_tx} end]}
    ] do
      state = Mutation.execute(bid_mutation, state)

      assert {:ok,
              Model.auction_bid(
                index: ^plain_name,
                start_height: ^claim_height,
                owner: ^owner_pk,
                expire_height: ^expire_height,
                claims_count: 2
              )} = State.get(state, Model.AuctionBid, plain_name)

      assert State.exists?(state, Model.AuctionOwner, {owner_pk, plain_name})
      assert State.exists?(state, Model.AuctionBidClaim, {plain_name, claim_height, txi_idx})

      assert State.exists?(
               state,
               Model.AuctionExpiration,
               {expire_height, plain_name}
             )

      assert State.exists?(
               state,
               Model.AuctionBidClaim,
               {plain_name, claim_height, next_txi_idx}
             )

      almost_expired_txi = txi + 2
      state = State.put(state, Model.Tx, Model.tx(index: almost_expired_txi, id: <<3::256>>))

      bid_mutation_2 =
        NameClaimMutation.new(
          plain_name,
          name_hash,
          owner_pk,
          name_fee,
          false,
          {almost_expired_txi, -1},
          {claim_height + 100, 0},
          protocol_version
        )

      state = Mutation.execute(bid_mutation_2, state)

      assert {:ok,
              Model.auction_bid(
                index: ^plain_name,
                start_height: ^claim_height,
                owner: ^owner_pk,
                expire_height: ^expire_height,
                claims_count: 3
              )} = State.get(state, Model.AuctionBid, plain_name)

      bid_mutation_3 =
        NameClaimMutation.new(
          plain_name,
          name_hash,
          owner_pk,
          name_fee,
          false,
          {almost_expired_txi + 1, -1},
          {claim_height + timeout - 10, 0},
          protocol_version
        )

      state = Mutation.execute(bid_mutation_3, state)

      expire_height = claim_height + timeout - 10 + extension

      assert {:ok,
              Model.auction_bid(
                index: ^plain_name,
                start_height: ^claim_height,
                owner: ^owner_pk,
                expire_height: ^expire_height,
                claims_count: 4
              )} = State.get(state, Model.AuctionBid, plain_name)
    end
  end
end
