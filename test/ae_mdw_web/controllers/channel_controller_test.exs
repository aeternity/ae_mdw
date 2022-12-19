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
      channel_pk = TS.channel_pk(0)

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      channel =
        Model.channel(
          index: channel_pk,
          active: 1,
          initiator: TS.address(0),
          responder: TS.address(0),
          state_hash: state_hash,
          amount: 5,
          updates: [{{1, 1}, 1}]
        )

      with_mocks [
        {Txs, [],
         fetch!: fn _state, 1 ->
           %{"block_hash" => "", "hash" => "", "tx" => %{"type" => "ChannelWithdrawTx"}}
         end}
      ] do
        store =
          store
          |> Store.put(Model.ActiveChannel, channel)
          |> Store.put(Model.ActiveChannelActivation, Model.activation(index: {1, channel_pk}))
          |> Store.put(Model.Tx, Model.tx(index: 1))

        assert %{"data" => [channel]} =
                 conn |> with_store(store) |> get("/v2/channels", limit: 1) |> json_response(200)

        assert %{"amount" => 5, "updates_count" => 1} = channel
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
    test "it returns an active/inactive channel", %{conn: conn, store: store} do
      active_channel_pk = TS.channel_pk(0)
      inactive_channel_pk = TS.channel_pk(1)
      active_channel_id = encode(:channel, active_channel_pk)
      inactive_channel_id = encode(:channel, inactive_channel_pk)
      initiator_pk = TS.address(0)
      initiator = encode_account(initiator_pk)
      responder_pk = TS.address(1)
      responder = encode_account(responder_pk)

      {:ok, state_hash} =
        :aeser_api_encoder.safe_decode(
          :state,
          "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+"
        )

      active_channel =
        Model.channel(
          index: active_channel_pk,
          active: 1,
          initiator: initiator_pk,
          responder: responder_pk,
          state_hash: state_hash,
          updates: [{{600_000, 1}, 1}]
        )

      inactive_channel = Model.channel(active_channel, index: inactive_channel_pk)
      block_hash = <<Enum.random(1_000..9_999)::256>>

      with_mocks [
        {Txs, [],
         fetch!: fn _state, 1 ->
           %{
             "block_hash" => encode(:micro_block_hash, block_hash),
             "hash" => "",
             "tx" => %{"type" => "ChannelWithdrawTx"}
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
          |> Store.put(Model.Tx, Model.tx(index: 1))

        assert %{
                 "channel" => ^active_channel_id,
                 "active" => true,
                 "amount" => 9_000_000,
                 "last_updated_height" => 600_000,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{active_channel_id}")
                 |> json_response(200)

        assert %{
                 "channel" => ^inactive_channel_id,
                 "active" => false,
                 "amount" => 8_000_000,
                 "last_updated_height" => 600_000,
                 "updates_count" => 1,
                 "responder" => ^responder,
                 "initiator" => ^initiator,
                 "channel_reserve" => 500_000,
                 "initiator_amount" => 4_400_000,
                 "responder_amount" => 4_600_000,
                 "round" => 1,
                 "solo_round" => 2,
                 "lock_period" => 3,
                 "locked_until" => 600_003
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/channels/#{inactive_channel_id}")
                 |> json_response(200)
      end
    end
  end
end
