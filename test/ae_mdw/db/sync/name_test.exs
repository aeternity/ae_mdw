defmodule AeMdw.Db.Sync.NameTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.NameUpdateMutation

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
            txi,
            block_index,
            timeout
          )
          | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
        ]

        assert ^mutations = Name.name_claim_mutations(tx_rec, tx_hash, block_index, txi)
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
            txi,
            block_index,
            0
          )
          | Origin.origin_mutations(:name_claim_tx, nil, name_hash, txi, tx_hash)
        ]

        assert ^mutations = Name.name_claim_mutations(tx_rec, tx_hash, block_index, txi)
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
end
