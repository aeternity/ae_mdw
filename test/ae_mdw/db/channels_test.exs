defmodule AeMdw.Db.ChannelsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Channels
  alias AeMdw.Db.ChannelCloseMutation
  alias AeMdw.Db.ChannelSpendMutation
  alias AeMdw.Db.ChannelUpdateMutation
  alias AeMdw.TestSamples, as: TS

  describe "close_mutual_mutations/2" do
    test "builds a ChannelCloseMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}
      release_amount = 3

      mutation = ChannelCloseMutation.new(channel_pk, bi_txi_idx, release_amount)

      {:ok, close_mutual_aetx} =
        :aesc_close_mutual_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          initiator_amount_final: 1,
          responder_amount_final: 2,
          ttl: 3,
          fee: 4,
          nonce: 5
        })

      {:channel_close_mutual_tx, close_mutual_tx} = :aetx.specialize_type(close_mutual_aetx)

      mutations = Channels.close_mutual_mutations(bi_txi_idx, close_mutual_tx)

      assert mutation in mutations
    end
  end

  describe "close_solo_mutations/2" do
    test "builds a ChannelUpdateMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}
      trees = :aec_trees.new()
      poi = :aec_trees.new_poi(trees)

      mutation = ChannelUpdateMutation.new(channel_pk, bi_txi_idx)

      {:ok, close_solo_aetx} =
        :aesc_close_solo_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          payload: "",
          poi: poi,
          fee: 1,
          nonce: 2
        })

      {:channel_close_solo_tx, close_solo_tx} = :aetx.specialize_type(close_solo_aetx)

      mutations = Channels.close_solo_mutations(bi_txi_idx, close_solo_tx)

      assert mutation in mutations
    end
  end

  describe "set_delegates_mutations/2" do
    test "builds a ChannelUpdateMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}

      mutation = ChannelUpdateMutation.new(channel_pk, bi_txi_idx)

      {:ok, set_delegates_aetx} =
        :aesc_set_delegates_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          initiator_delegate_ids: [],
          responder_delegate_ids: [],
          payload: "",
          state_hash: "",
          round: 1,
          ttl: 2,
          fee: 3,
          nonce: 4
        })

      {:channel_set_delegates_tx, set_delegates_tx} = :aetx.specialize_type(set_delegates_aetx)

      mutations = Channels.set_delegates_mutations(bi_txi_idx, set_delegates_tx)

      assert mutation in mutations
    end
  end

  describe "force_progress_mutations/2" do
    test "builds a ChannelUpdateMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}
      account_pk1 = :aeser_id.create(:account, TS.address(2))
      account_pk2 = :aeser_id.create(:account, TS.address(3))
      update = :aesc_offchain_update.op_transfer(account_pk1, account_pk2, 30)
      trees = :aec_trees.new()

      mutation = ChannelUpdateMutation.new(channel_pk, bi_txi_idx)

      {:ok, force_progress_aetx} =
        :aesc_force_progress_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          payload: "",
          update: update,
          state_hash: "",
          round: 1,
          offchain_trees: trees,
          fee: 3,
          nonce: 4
        })

      {:channel_force_progress_tx, force_progress_tx} = :aetx.specialize_type(force_progress_aetx)

      mutations = Channels.force_progress_mutations(bi_txi_idx, force_progress_tx)

      assert mutation in mutations
    end
  end

  describe "slash_mutations/2" do
    test "builds a ChannelUpdateMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}
      trees = :aec_trees.new()
      poi = :aec_trees.new_poi(trees)

      mutation = ChannelUpdateMutation.new(channel_pk, bi_txi_idx)

      {:ok, slash_aetx} =
        :aesc_slash_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          payload: "",
          poi: poi,
          fee: 3,
          nonce: 4
        })

      {:channel_slash_tx, slash_tx} = :aetx.specialize_type(slash_aetx)

      mutations = Channels.slash_mutations(bi_txi_idx, slash_tx)

      assert mutation in mutations
    end
  end

  describe "deposit_mutations/2" do
    test "builds a ChannelSpendMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      mutation = ChannelSpendMutation.new(channel_pk, bi_txi_idx, 23)

      {:ok, deposit_aetx} =
        :aesc_deposit_tx.new(%{
          channel_id: channel_id,
          from_id: account_id,
          amount: 23,
          fee: 3,
          state_hash: state_hash,
          round: 4,
          nonce: 5
        })

      {:channel_deposit_tx, deposit_tx} = :aetx.specialize_type(deposit_aetx)

      mutations = Channels.deposit_mutations(bi_txi_idx, deposit_tx)

      assert mutation in mutations
    end
  end

  describe "withdraw_mutations/2" do
    test "builds a ChannelSpendMutation" do
      channel_pk = TS.address(0)
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id = :aeser_id.create(:account, TS.address(1))
      bi_txi_idx = {{123, 0}, {456, -1}}

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      mutation = ChannelSpendMutation.new(channel_pk, bi_txi_idx, -23)

      {:ok, withdraw_aetx} =
        :aesc_withdraw_tx.new(%{
          channel_id: channel_id,
          to_id: account_id,
          amount: 23,
          fee: 3,
          state_hash: state_hash,
          round: 4,
          nonce: 5
        })

      {:channel_withdraw_tx, withdraw_tx} = :aetx.specialize_type(withdraw_aetx)

      mutations = Channels.withdraw_mutations(bi_txi_idx, withdraw_tx)

      assert mutation in mutations
    end
  end
end
