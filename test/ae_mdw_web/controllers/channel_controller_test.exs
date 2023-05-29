defmodule AeMdwWeb.ChannelControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.TestSamples, as: TS

  import Mock
  import AeMdw.Util.Encoding

  require Model

  describe "channels" do
    test "it returns active and inactive channels", %{conn: conn, store: store} do
      channel_pk1 = <<0::256>>
      channel_pk2 = <<1::256>>
      channel_pk3 = <<2::256>>
      initiator_pk = <<3::256>>
      responder_pk = <<4::256>>
      tx_hash = <<5::256>>
      block_hash = <<6::256>>
      enc_tx_hash = encode(:tx_hash, tx_hash)
      channel_id1 = encode(:channel, channel_pk1)
      channel_id2 = encode(:channel, channel_pk2)
      channel_id3 = encode(:channel, channel_pk3)
      initiator = encode_account(initiator_pk)
      responder = encode_account(responder_pk)

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      encoded_state_hash = encode(:state, state_hash)

      m_channel1 =
        Model.channel(
          index: channel_pk1,
          active: 1,
          initiator: initiator_pk,
          responder: responder_pk,
          state_hash: state_hash,
          updates: [{{500_000, 1}, {1_000, -1}}]
        )

      m_channel2 =
        Model.channel(m_channel1,
          index: channel_pk2,
          active: 2,
          updates: [{{500_000, 1}, {2_000, -1}}]
        )

      m_channel3 =
        Model.channel(m_channel1,
          index: channel_pk3,
          active: 3,
          updates: [{{600_000, 1}, {3_000, -1}}]
        )

      with_mocks [
        {AeMdw.Db.Util, [:passthrough],
         [
           read_node_tx_details: fn
             _state, {1_000, -1} ->
               {:tx, :channel_withdraw_tx, tx_hash, :channel_withdraw_tx, block_hash}

             _state, {2_000, -1} ->
               {:tx, :channel_close_mutual_tx, tx_hash, :channel_close_mutual_tx, block_hash}

             _state, {3_000, -1} ->
               {:tx, :channel_deposit_tx, tx_hash, :channel_deposit_tx, block_hash}
           end
         ]},
        {:aec_chain, [:passthrough],
         get_channel_at_hash: fn pubkey, ^block_hash ->
           amount =
             if pubkey == channel_pk1,
               do: 9_000_000,
               else: 8_000_000

           {:ok,
            {:channel, {:id, :channel, pubkey}, {:id, :account, initiator_pk},
             {:id, :account, responder_pk}, %{initiator: [], responder: []}, amount, 3_400_000,
             3_600_000, 500_000, :basic, :basic,
             <<13, 54, 141, 196, 223, 107, 172, 150, 198, 45, 62, 102, 159, 21, 123, 151, 241,
               235, 20, 175, 223, 198, 242, 127, 137, 194, 129, 204, 227, 139, 197, 132>>, 1, 2,
             3, 500_003, 3}}
         end}
      ] do
        store =
          store
          |> Store.put(Model.ActiveChannel, m_channel1)
          |> Store.put(Model.ActiveChannel, m_channel2)
          |> Store.put(Model.ActiveChannelActivation, Model.activation(index: {1, channel_pk1}))
          |> Store.put(Model.ActiveChannelActivation, Model.activation(index: {2, channel_pk2}))
          |> Store.put(Model.InactiveChannel, m_channel3)
          |> Store.put(Model.InactiveChannelActivation, Model.activation(index: {3, channel_pk3}))

        assert %{"data" => [channel3, channel2] = channels, "next" => next_url} =
                 conn |> with_store(store) |> get("/v2/channels", limit: 2) |> json_response(200)

        assert %{
                 "channel" => ^channel_id3,
                 "active" => false,
                 "amount" => 8_000_000,
                 "last_updated_height" => 600_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => "ChannelDepositTx",
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 3_400_000,
                 "responder_amount" => 3_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 500_003,
                 "state_hash" => ^encoded_state_hash
               } = channel3

        assert %{
                 "channel" => ^channel_id2,
                 "active" => true,
                 "amount" => 8_000_000,
                 "last_updated_height" => 500_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => "ChannelCloseMutualTx",
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 3_400_000,
                 "responder_amount" => 3_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 500_003,
                 "state_hash" => ^encoded_state_hash
               } = channel2

        assert %{"data" => [channel1], "prev" => prev_url} =
                 conn |> with_store(store) |> get(next_url) |> json_response(200)

        assert %{
                 "channel" => ^channel_id1,
                 "active" => true,
                 "amount" => 9_000_000,
                 "last_updated_height" => 500_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => "ChannelWithdrawTx",
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 3_400_000,
                 "responder_amount" => 3_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 500_003,
                 "state_hash" => ^encoded_state_hash
               } = channel1

        assert %{"data" => ^channels} =
                 conn |> with_store(store) |> get(prev_url) |> json_response(200)
      end
    end

    test "when no channels, it returns empty data", %{conn: conn, store: store} do
      assert %{"data" => []} =
               conn |> with_store(store) |> get("/v2/channels") |> json_response(200)
    end

    test "when no invalid cursor, it returns error", %{conn: conn, store: store} do
      assert %{"error" => "invalid cursor: foo"} =
               conn
               |> with_store(store)
               |> get("/v2/channels", cursor: "foo")
               |> json_response(400)
    end
  end

  describe "channel" do
    test "returns an active/inactive channel on latest update state", %{conn: conn, store: store} do
      active_channel_pk = TS.channel_pk(0)
      inactive_channel_pk = TS.channel_pk(1)
      initiator_pk = TS.address(0)
      responder_pk = TS.address(1)
      tx_hash = <<Enum.random(1_000..9_999)::256>>
      enc_tx_hash = encode(:tx_hash, tx_hash)
      tx_type1 = "ChannelWithdrawTx"
      tx_type2 = "ChannelCloseMutualTx"
      state_hash1 = <<1::256>>
      state_hash2 = <<2::256>>

      active_channel =
        Model.channel(
          index: active_channel_pk,
          active: 1,
          initiator: initiator_pk,
          responder: responder_pk,
          state_hash: state_hash1,
          updates: [{{600_000, 1}, {1_000, -1}}]
        )

      inactive_channel =
        Model.channel(active_channel,
          index: inactive_channel_pk,
          state_hash: state_hash2,
          updates: [{{600_000, 1}, {2_000, -1}}]
        )

      block_hash = <<Enum.random(1_000..9_999)::256>>

      with_mocks [
        {AeMdw.Db.Util, [:passthrough],
         [
           read_node_tx_details: fn
             _state, {1_000, -1} ->
               {:tx, :channel_withdraw_tx, tx_hash, :channel_withdraw_tx, block_hash}

             _state, {2_000, -1} ->
               {:tx, :channel_close_mutual_tx, tx_hash, :channel_close_mutual_tx, block_hash}
           end
         ]},
        {:aec_chain, [:passthrough],
         get_channel_at_hash: fn pubkey, ^block_hash ->
           amount =
             if pubkey == active_channel_pk,
               do: 9_000_000,
               else: 8_000_000

           {:ok,
            {:channel, {:id, :channel, pubkey}, {:id, :account, initiator_pk},
             {:id, :account, responder_pk}, %{initiator: [], responder: []}, amount, 4_400_000,
             4_600_000, 500_000, :basic, :basic,
             <<13, 54, 141, 196, 223, 107, 172, 150, 198, 45, 62, 102, 159, 21, 123, 151, 241,
               235, 20, 175, 223, 198, 242, 127, 137, 194, 129, 204, 227, 139, 197, 132>>, 1, 2,
             3, 600_003, 3}}
         end}
      ] do
        store =
          store
          |> Store.put(Model.ActiveChannel, active_channel)
          |> Store.put(Model.InactiveChannel, inactive_channel)

        active_channel_id = encode(:channel, active_channel_pk)
        inactive_channel_id = encode(:channel, inactive_channel_pk)
        initiator = encode_account(initiator_pk)
        responder = encode_account(responder_pk)
        state_hash = encode(:state, state_hash1)

        assert %{
                 "channel" => ^active_channel_id,
                 "active" => true,
                 "amount" => 9_000_000,
                 "last_updated_height" => 600_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => ^tx_type1,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003,
                 "state_hash" => ^state_hash
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{active_channel_id}")
                 |> json_response(200)

        state_hash = encode(:state, state_hash2)

        assert %{
                 "channel" => ^inactive_channel_id,
                 "active" => false,
                 "amount" => 8_000_000,
                 "last_updated_height" => 600_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => ^tx_type2,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003,
                 "state_hash" => ^state_hash
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{inactive_channel_id}")
                 |> json_response(200)
      end
    end

    test "returns an active/inactive channel on micro block state", %{conn: conn, store: store} do
      active_channel_pk = TS.channel_pk(0)
      inactive_channel_pk = TS.channel_pk(1)
      initiator_pk = TS.address(0)
      responder_pk = TS.address(1)
      tx_hash = <<Enum.random(1_000..9_999)::256>>
      enc_tx_hash = encode(:tx_hash, tx_hash)
      tx_type1 = "ChannelWithdrawTx"
      tx_type2 = "ChannelCloseMutualTx"
      state_hash1 = <<1::256>>
      state_hash2 = <<2::256>>

      active_channel =
        Model.channel(
          index: active_channel_pk,
          active: 1,
          initiator: initiator_pk,
          responder: responder_pk,
          state_hash: state_hash1,
          updates: [{{600_000, 1}, {1_000, -1}}]
        )

      inactive_channel =
        Model.channel(active_channel,
          index: inactive_channel_pk,
          state_hash: state_hash2,
          updates: [{{600_000, 1}, {2_000, -1}}]
        )

      update_block_hash = :crypto.strong_rand_bytes(32)
      micro_block_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aec_chain, [:passthrough],
         get_channel_at_hash: fn pubkey, ^micro_block_hash ->
           amount =
             if pubkey == active_channel_pk,
               do: 9_000_000,
               else: 8_000_000

           {:ok,
            {:channel, {:id, :channel, pubkey}, {:id, :account, initiator_pk},
             {:id, :account, responder_pk}, %{initiator: [], responder: []}, amount, 4_400_000,
             4_600_000, 500_000, :basic, :basic,
             <<13, 54, 141, 196, 223, 107, 172, 150, 198, 45, 62, 102, 159, 21, 123, 151, 241,
               235, 20, 175, 223, 198, 242, 127, 137, 194, 129, 204, 227, 139, 197, 132>>, 1, 2,
             3, 600_003, 3}}
         end},
        {AeMdw.Db.Util, [:passthrough],
         [
           read_node_tx_details: fn
             _state, {1_000, -1} ->
               {:tx, :channel_withdraw_tx, tx_hash, :channel_withdraw_tx, update_block_hash}

             _state, {2_000, -1} ->
               {:tx, :channel_close_mutual_tx, tx_hash, :channel_close_mutual_tx,
                update_block_hash}
           end,
           micro_block_height_index: fn _state, ^micro_block_hash -> {:ok, 599_999, 1} end
         ]}
      ] do
        store =
          store
          |> Store.put(Model.ActiveChannel, active_channel)
          |> Store.put(Model.InactiveChannel, inactive_channel)

        active_channel_id = encode(:channel, active_channel_pk)
        inactive_channel_id = encode(:channel, inactive_channel_pk)
        initiator = encode_account(initiator_pk)
        responder = encode_account(responder_pk)
        state_hash = encode(:state, state_hash1)

        assert %{
                 "channel" => ^active_channel_id,
                 "active" => true,
                 "amount" => 9_000_000,
                 "last_updated_height" => 600_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => ^tx_type1,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003,
                 "state_hash" => ^state_hash
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{active_channel_id}",
                   block_hash: encode(:micro_block_hash, micro_block_hash)
                 )
                 |> json_response(200)

        state_hash = encode(:state, state_hash2)

        assert %{
                 "channel" => ^inactive_channel_id,
                 "active" => false,
                 "amount" => 8_000_000,
                 "last_updated_height" => 600_000,
                 "last_updated_tx_hash" => ^enc_tx_hash,
                 "last_updated_tx_type" => ^tx_type2,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003,
                 "state_hash" => ^state_hash
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{inactive_channel_id}",
                   block_hash: encode(:micro_block_hash, micro_block_hash)
                 )
                 |> json_response(200)
      end
    end

    test "returns error when channel does not exist", %{conn: conn, store: store} do
      channel_id = encode(:channel, :crypto.strong_rand_bytes(32))
      msg = "not found: #{channel_id}"

      assert %{"error" => ^msg} =
               conn
               |> with_store(store)
               |> get("/v2/channels/#{channel_id}")
               |> json_response(404)
    end

    test "returns error when block is invalid", %{conn: conn, store: store} do
      channel_pk = :crypto.strong_rand_bytes(32)
      store = Store.put(store, Model.ActiveChannel, Model.channel(index: channel_pk))

      assert %{"error" => "invalid id: kh_123"} =
               conn
               |> with_store(store)
               |> get("/v2/channels/#{encode(:channel, channel_pk)}", block_hash: "kh_123")
               |> json_response(400)
    end
  end

  describe "channel_updates" do
    test "returns a channel's updates", %{conn: conn, store: store} do
      [txi_idx1, txi_idx2, txi_idx3] = [{1, -1}, {2, 0}, {3, -1}]
      updates = [{{3, 0}, txi_idx3}, {{4, 0}, txi_idx2}, {{1, 0}, txi_idx1}]
      channel_pk = <<1::256>>
      account_pk1 = <<7::256>>
      account_pk2 = <<8::256>>
      channel_id = :aeser_id.create(:channel, channel_pk)
      account_id1 = :aeser_id.create(:account, account_pk1)
      account_id2 = :aeser_id.create(:account, account_pk2)
      encoded_account_id1 = Enc.encode(:account_pubkey, account_pk1)
      encoded_account_id2 = Enc.encode(:account_pubkey, account_pk2)
      encoded_channel_pk = Enc.encode(:channel, channel_pk)
      tx_hash1 = <<10::256>>
      tx_hash2 = <<11::256>>
      tx_hash3 = <<12::256>>
      block_hash = <<13::256>>

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      channel =
        Model.channel(
          index: channel_pk,
          updates: updates
        )

      store = Store.put(store, Model.ActiveChannel, channel)

      {:ok, channel_deposit_aetx1} =
        :aesc_deposit_tx.new(%{
          channel_id: channel_id,
          from_id: account_id1,
          amount: 1,
          ttl: 11,
          fee: 111,
          state_hash: state_hash,
          round: 1_111,
          nonce: 11_111
        })

      {:ok, channel_settle_aetx2} =
        :aesc_settle_tx.new(%{
          channel_id: channel_id,
          from_id: account_id2,
          initiator_amount_final: 2,
          responder_amount_final: 22,
          fee: 222,
          nonce: 2_222
        })

      {:ok, channel_deposit_aetx3} =
        :aesc_deposit_tx.new(%{
          channel_id: channel_id,
          from_id: account_id2,
          amount: 3,
          ttl: 33,
          fee: 333,
          state_hash: state_hash,
          round: 3_333,
          nonce: 33_333
        })

      {:channel_deposit_tx, channel_deposit_tx1} = :aetx.specialize_type(channel_deposit_aetx1)
      {:channel_settle_tx, channel_settle_tx2} = :aetx.specialize_type(channel_settle_aetx2)
      {:channel_deposit_tx, channel_deposit_tx3} = :aetx.specialize_type(channel_deposit_aetx3)

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn
             _state, ^txi_idx1 ->
               {channel_deposit_tx1, :channel_deposit_tx, tx_hash1, :channel_deposit_tx,
                block_hash}

             _state, ^txi_idx2 ->
               {channel_settle_tx2, :channel_settle_tx, tx_hash2, :contract_call_tx, block_hash}

             _state, ^txi_idx3 ->
               {channel_deposit_tx3, :channel_deposit_tx, tx_hash3, :channel_deposit_tx,
                block_hash}
           end
         ]}
      ] do
        assert %{"data" => [update3, update2] = updates, "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{encode(:channel, channel_pk)}/updates", limit: 2)
                 |> json_response(200)

        assert %{
                 "source_tx_type" => "ChannelDepositTx",
                 "tx" => %{
                   "channel_id" => ^encoded_channel_pk,
                   "nonce" => 33_333,
                   "from_id" => ^encoded_account_id2,
                   "fee" => 333
                 }
               } = update3

        assert %{
                 "source_tx_type" => "ContractCallTx",
                 "tx" => %{
                   "channel_id" => ^encoded_channel_pk,
                   "nonce" => 2_222,
                   "from_id" => ^encoded_account_id2,
                   "fee" => 222
                 }
               } = update2

        assert %{"data" => [update1], "prev" => prev_url} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "source_tx_type" => "ChannelDepositTx",
                 "tx" => %{
                   "channel_id" => ^encoded_channel_pk,
                   "nonce" => 11_111,
                   "from_id" => ^encoded_account_id1,
                   "fee" => 111
                 }
               } = update1

        assert %{"data" => ^updates} =
                 conn
                 |> with_store(store)
                 |> get(prev_url)
                 |> json_response(200)
      end
    end

    test "returns error when channel is not found", %{conn: conn, store: store} do
      channel_pk = :crypto.strong_rand_bytes(32)
      encoded_channel_id = encode(:channel, channel_pk)
      error_msg = "not found: #{encoded_channel_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/channels/#{encoded_channel_id}/updates")
               |> json_response(404)
    end

    test "returns error when channel id is invalid", %{conn: conn, store: store} do
      invalid_id = "foo"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/channels/#{invalid_id}/updates")
               |> json_response(400)
    end
  end
end
