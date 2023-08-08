defmodule AeMdw.Db.Sync.NameTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS

  import Mock

  require Model

  describe "name_claim_mutations/4" do
    test "includes origin mutations for auction name" do
      plain_name = "auction-name.chain"
      owner_pk = <<1::256>>
      name_fee = 1_000_000

      timeout =
        :aec_governance.name_claim_bid_timeout(plain_name, :aec_hard_forks.protocol_vsn(:lima))

      height = AeMdw.Node.lima_height() + Enum.random(100..999)
      block_index = {height, 1}
      txi = height * 1_000
      txi_idx = {txi, -1}
      tx_hash = <<txi::256>>

      {:ok, aetx} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, owner_pk),
          nonce: 1,
          name: plain_name,
          name_fee: name_fee,
          name_salt: 123_456,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      name_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutations = [
          NameClaimMutation.new(
            plain_name,
            name_hash,
            owner_pk,
            name_fee,
            true,
            txi_idx,
            block_index,
            timeout
          )
          | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
        ]

        assert ^mutations = Name.name_claim_mutations(tx_rec, tx_hash, block_index, txi_idx)
      end
    end

    test "includes origin mutations for big name" do
      plain_name = "some-big-name.chain"
      owner_pk = <<1::256>>
      name_fee = 500_000

      height = AeMdw.Node.lima_height() + Enum.random(100..999)
      block_index = {height, 1}
      txi = height * 1000
      tx_hash = <<txi::256>>

      {:ok, aetx} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, owner_pk),
          nonce: 1,
          name: plain_name,
          name_fee: name_fee,
          name_salt: 123_456,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      name_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutations = [
          NameClaimMutation.new(
            plain_name,
            name_hash,
            owner_pk,
            name_fee,
            true,
            {txi, -1},
            block_index,
            0
          )
          | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
        ]

        assert ^mutations = Name.name_claim_mutations(tx_rec, tx_hash, block_index, {txi, -1})
      end
    end
  end

  describe "update_mutations/4" do
    test "updates name and expiration on ttl > 0" do
      plain_name = "some-name.chain"
      block_index = {Enum.random(100_000..200_000), 1}
      txi = Enum.random(100_000_000..999_999_999)
      absolute_ttl = 100
      name_hash = :crypto.strong_rand_bytes(32)

      pointers = [
        {:pointer, <<2::256>>, :aeser_id.create(:account, <<3::256>>)},
        {:pointer, <<4::256>>, :aeser_id.create(:account, <<5::256>>)}
      ]

      {:ok, aetx} =
        :aens_update_tx.new(%{
          account_id: :aeser_id.create(:account, <<1::256>>),
          nonce: 1,
          name_id: :aeser_id.create(:name, name_hash),
          name_ttl: absolute_ttl,
          pointers: pointers,
          client_ttl: absolute_ttl,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutation =
          NameUpdateMutation.new(
            name_hash,
            {:update_expiration, absolute_ttl},
            pointers,
            txi,
            block_index
          )

        assert [^mutation] = Name.update_mutations(tx_rec, txi, block_index, true)
      end
    end

    test "updates name and expiration on delta ttl > 0" do
      plain_name = "some-name.chain"
      block_index = {height, _mbi} = {Enum.random(100_000..200_000), 1}
      txi = Enum.random(100_000_000..999_999_999)
      delta_ttl = 100
      name_hash = :crypto.strong_rand_bytes(32)

      pointers = [
        {:pointer, <<2::256>>, :aeser_id.create(:account, <<3::256>>)},
        {:pointer, <<4::256>>, :aeser_id.create(:account, <<5::256>>)}
      ]

      {:ok, aetx} =
        :aens_update_tx.new(%{
          account_id: :aeser_id.create(:account, <<1::256>>),
          nonce: 1,
          name_id: :aeser_id.create(:name, name_hash),
          name_ttl: delta_ttl,
          pointers: pointers,
          client_ttl: delta_ttl,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutation =
          NameUpdateMutation.new(
            name_hash,
            {:update_expiration, delta_ttl + height},
            pointers,
            txi,
            block_index
          )

        assert [^mutation] = Name.update_mutations(tx_rec, txi, block_index, false)
      end
    end

    test "ignores zero ttl and update when call is internal" do
      plain_name = "some-name.chain"
      block_index = {Enum.random(100_000..200_000), 1}
      txi = Enum.random(100_000_000..999_999_999)
      ttl = 0
      name_hash = :crypto.strong_rand_bytes(32)

      pointers = [
        {:pointer, <<2::256>>, :aeser_id.create(:account, <<3::256>>)},
        {:pointer, <<4::256>>, :aeser_id.create(:account, <<5::256>>)}
      ]

      {:ok, aetx} =
        :aens_update_tx.new(%{
          account_id: :aeser_id.create(:account, <<1::256>>),
          nonce: 1,
          name_id: :aeser_id.create(:name, name_hash),
          name_ttl: ttl,
          pointers: pointers,
          client_ttl: ttl,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutation = NameUpdateMutation.new(name_hash, :update, pointers, txi, block_index)

        assert [^mutation] = Name.update_mutations(tx_rec, txi, block_index, true)
      end
    end

    test "expires the name on zero ttl when call is not internal" do
      plain_name = "some-name.chain"
      block_index = {Enum.random(100_000..200_000), 1}
      txi = Enum.random(100_000_000..999_999_999)
      ttl = 0
      name_hash = :crypto.strong_rand_bytes(32)
      pointers = []

      {:ok, aetx} =
        :aens_update_tx.new(%{
          account_id: :aeser_id.create(:account, <<1::256>>),
          nonce: 1,
          name_id: :aeser_id.create(:name, name_hash),
          name_ttl: ttl,
          pointers: pointers,
          client_ttl: ttl,
          fee: 100
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      with_mocks [
        {:aens, [:passthrough], get_name_hash: fn ^plain_name -> {:ok, name_hash} end}
      ] do
        mutation = NameUpdateMutation.new(name_hash, :expire, pointers, txi, block_index)

        assert [^mutation] = Name.update_mutations(tx_rec, txi, block_index, false)
      end
    end
  end

  describe "transfer/5" do
    test "it creates a ActiveNameOwnerDeactivation and removes the previous one" do
      plain_name = TS.plain_name(0)
      name_hash = "some-hash"
      block_index = {123, 456}
      txi = 789
      old_owner = TS.address(0)
      new_owner = TS.address(1)
      expire = 987_654

      name = Model.name(index: plain_name, expire: expire, owner: old_owner)
      owner_deactivation = Model.owner_deactivation(index: {old_owner, expire, plain_name})

      state =
        empty_store()
        |> Store.put(Model.ActiveName, name)
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
        |> Store.put(Model.ActiveNameOwnerDeactivation, owner_deactivation)
        |> State.new()

      state = Name.transfer(state, name_hash, new_owner, txi, block_index)

      refute State.exists?(
               state,
               Model.ActiveNameOwnerDeactivation,
               {old_owner, expire, plain_name}
             )

      assert State.exists?(
               state,
               Model.ActiveNameOwnerDeactivation,
               {new_owner, expire, plain_name}
             )
    end
  end

  describe "update/6" do
    test "it creates a ActiveNameOwnerDeactivation and removes the previous one" do
      plain_name = TS.plain_name(0)
      name_hash = "some-hash"
      block_index = {123, 456}
      txi = 789
      owner = TS.address(0)
      old_expire = 987_654
      new_expire = 321_098
      pointers = []
      update_type = {:update_expiration, new_expire}

      name = Model.name(index: plain_name, expire: old_expire, owner: owner)
      owner_deactivation = Model.owner_deactivation(index: {owner, old_expire, plain_name})

      state =
        empty_store()
        |> Store.put(Model.ActiveName, name)
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
        |> Store.put(Model.ActiveNameOwnerDeactivation, owner_deactivation)
        |> State.new()

      state = Name.update(state, name_hash, update_type, pointers, txi, block_index)

      refute State.exists?(
               state,
               Model.ActiveNameOwnerDeactivation,
               {owner, old_expire, plain_name}
             )

      assert State.exists?(
               state,
               Model.ActiveNameOwnerDeactivation,
               {owner, new_expire, plain_name}
             )
    end
  end

  describe "expire_auction/3" do
    test "it creates new NameClaim records using the AuctionBidClaims" do
      plain_name = TS.plain_name(0)
      height = 125
      txi_idx1 = {123, -1}
      txi_idx2 = {124, 0}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          block_index_txi_idx: {{1, 2}, {3, -1}},
          expire_height: height,
          owner: <<0::256>>
        )

      tx_hash = <<1::256>>

      {:ok, claim_aetx} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, <<0::256>>),
          nonce: 1,
          name: plain_name,
          name_salt: 123_456,
          name_fee: 123,
          fee: 5_000
        })

      {:name_claim_tx, claim_tx} = :aetx.specialize_type(claim_aetx)

      state =
        empty_store()
        |> Store.put(Model.AuctionBid, auction_bid)
        |> Store.put(
          Model.AuctionBidClaim,
          Model.name_claim(index: {plain_name, height, txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.name_claim(index: {plain_name, height, txi_idx2})
        )
        |> Store.put(Model.Tx, Model.tx(index: 3, id: tx_hash))
        |> State.new()

      with_mocks [
        {Db, [:passthrough],
         [get_tx_data: fn ^tx_hash -> {<<456::256>>, :name_claim_tx, :signed_tx, claim_tx} end]}
      ] do
        state = Name.expire_auction(state, height, plain_name)

        assert State.exists?(state, Model.NameClaim, {plain_name, height, txi_idx1})
        refute State.exists?(state, Model.AuctionBidClaim, {plain_name, height, txi_idx1})
        assert State.exists?(state, Model.NameClaim, {plain_name, height, txi_idx2})
        refute State.exists?(state, Model.AuctionBidClaim, {plain_name, height, txi_idx2})
      end
    end
  end

  defp empty_store, do: MemStore.new(NullStore.new())
end
