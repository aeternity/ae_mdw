defmodule AeMdw.Db.Sync.OracleTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.OracleResponseMutation

  require Model

  describe "register_mutations/4" do
    test "creates mutations including origin for the oracle" do
      pubkey = <<1::256>>
      block_index = {height, _mbi} = {Enum.random(100_000..999_999), 1}
      ttl = 10_000
      expire = height + ttl
      txi = height * 1000
      tx_hash = <<123_456::256>>
      txi_idx = {txi, -1}

      {:ok, aetx} =
        :aeo_register_tx.new(%{
          account_id: :aeser_id.create(:account, pubkey),
          nonce: 1,
          query_format: "{\"foo\": 0}",
          abi_version: 0,
          response_format: "{\"bar\": 1}",
          query_fee: 2_000_000,
          oracle_ttl: {:delta, ttl},
          fee: 2_000
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      mutations = [
        Origin.origin_mutations(:oracle_register_tx, nil, pubkey, txi, tx_hash),
        OracleRegisterMutation.new(pubkey, block_index, expire, txi_idx)
      ]

      assert ^mutations = Oracle.register_mutations(tx_rec, tx_hash, block_index, txi_idx)
    end
  end

  describe "response_mutation/4" do
    test "creates mutation for the oracle" do
      pubkey = <<2::256>>
      block_index = {Enum.random(100_000..999_999), 1}
      txi = Enum.random(100_000_000..999_999_999)
      fee = Enum.random(100..999)
      query_id = <<0::256>>

      {:ok, aetx} =
        :aeo_response_tx.new(%{
          oracle_id: :aeser_id.create(:oracle, pubkey),
          nonce: 1,
          query_id: query_id,
          response: "",
          response_ttl: {:delta, 0},
          fee: fee
        })

      {:oracle_response_tx, tx_rec} = :aetx.specialize_type(aetx)

      mutation = OracleResponseMutation.new(block_index, txi, pubkey, query_id)
      assert ^mutation = Oracle.response_mutation(tx_rec, block_index, txi)
    end
  end

  describe "extend_mutation/4" do
    test "creates mutation with ttl for the oracle" do
      pubkey = <<3::256>>
      block_index = {Enum.random(100_000..999_999), 1}
      txi = Enum.random(100_000_000..999_999_999)
      ttl = 10_000

      {:ok, aetx} =
        :aeo_extend_tx.new(%{
          oracle_id: :aeser_id.create(:oracle, pubkey),
          nonce: 1,
          oracle_ttl: {:delta, ttl},
          fee: 2_000
        })

      {_mod, tx_rec} = :aetx.specialize_callback(aetx)

      mutation = OracleExtendMutation.new(block_index, txi, pubkey, ttl)
      assert ^mutation = Oracle.extend_mutation(tx_rec, block_index, txi)
    end
  end
end
