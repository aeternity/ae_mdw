defmodule AeMdwWeb.ChannelControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs

  import Mock
  import AeMdw.Util.Encoding

  require Model

  describe "channels" do
    test "it returns active channels", %{conn: conn, store: store} do
      channel_pk1 = TS.channel_pk(0)
      channel_pk2 = TS.channel_pk(1)
      initiator_pk = TS.address(0)
      responder_pk = TS.address(1)
      tx_hash = encode(:tx_hash, <<Enum.random(1_000..9_999)::256>>)
      tx_type1 = "ChannelWithdrawTx"
      tx_type2 = "ChannelCloseMutualTx"

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      m_channel1 =
        Model.channel(
          index: channel_pk1,
          active: 1,
          initiator: initiator_pk,
          responder: responder_pk,
          state_hash: state_hash,
          updates: [{{500_000, 1}, 1_000}]
        )

      m_channel2 =
        Model.channel(m_channel1, index: channel_pk2, active: 2, updates: [{{500_000, 1}, 2_000}])

      block_hash = <<Enum.random(1_000..9_999)::256>>

      with_mocks [
        {Txs, [:passthrough],
         fetch!: fn _state, txi when txi in [1_000, 2_000] ->
           tx =
             if txi == 1_000 do
               %{"type" => tx_type1}
             else
               %{"type" => tx_type2}
             end

           %{
             "block_hash" => encode(:micro_block_hash, block_hash),
             "hash" => tx_hash,
             "tx" => tx
           }
         end},
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

        assert %{"data" => [channel2, channel1]} =
                 conn |> with_store(store) |> get("/v2/channels") |> json_response(200)

        channel_id1 = encode(:channel, channel_pk1)
        channel_id2 = encode(:channel, channel_pk2)
        initiator = encode_account(initiator_pk)
        responder = encode_account(responder_pk)
        state_hash = encode(:state, state_hash)

        assert %{
                 "channel" => ^channel_id2,
                 "active" => true,
                 "amount" => 8_000_000,
                 "last_updated_height" => 500_000,
                 "last_updated_tx_hash" => ^tx_hash,
                 "last_updated_tx_type" => ^tx_type2,
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
                 "state_hash" => ^state_hash
               } = channel2

        assert %{
                 "channel" => ^channel_id1,
                 "active" => true,
                 "amount" => 9_000_000,
                 "last_updated_height" => 500_000,
                 "last_updated_tx_hash" => ^tx_hash,
                 "last_updated_tx_type" => ^tx_type1,
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
                 "state_hash" => ^state_hash
               } = channel1
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
      tx_hash = encode(:tx_hash, <<Enum.random(1_000..9_999)::256>>)
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
          updates: [{{600_000, 1}, 1_000}]
        )

      inactive_channel =
        Model.channel(active_channel,
          index: inactive_channel_pk,
          state_hash: state_hash2,
          updates: [{{600_000, 1}, 2_000}]
        )

      block_hash = <<Enum.random(1_000..9_999)::256>>

      with_mocks [
        {Txs, [:passthrough],
         fetch!: fn _state, txi when txi in [1_000, 2_000] ->
           tx =
             if txi == 1_000 do
               %{"type" => tx_type1}
             else
               %{"type" => tx_type2}
             end

           %{
             "block_hash" => encode(:micro_block_hash, block_hash),
             "hash" => tx_hash,
             "tx" => tx
           }
         end},
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
                 "last_updated_tx_hash" => ^tx_hash,
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
                 "last_updated_tx_hash" => ^tx_hash,
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
      tx_hash = encode(:tx_hash, <<Enum.random(1_000..9_999)::256>>)
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
          updates: [{{600_000, 1}, 1_000}]
        )

      inactive_channel =
        Model.channel(active_channel,
          index: inactive_channel_pk,
          state_hash: state_hash2,
          updates: [{{600_000, 1}, 2_000}]
        )

      update_block_hash = :crypto.strong_rand_bytes(32)
      micro_block_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {Txs, [:passthrough],
         fetch!: fn _state, txi when txi in [1_000, 2_000] ->
           tx =
             if txi == 1_000 do
               %{"type" => tx_type1}
             else
               %{"type" => tx_type2}
             end

           %{
             "block_hash" => encode(:micro_block_hash, update_block_hash),
             "hash" => tx_hash,
             "tx" => tx
           }
         end},
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
         micro_block_height_index: fn _state, ^micro_block_hash -> {:ok, 599_999, 1} end}
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
                 "last_updated_tx_hash" => ^tx_hash,
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
                 "last_updated_tx_hash" => ^tx_hash,
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
end
