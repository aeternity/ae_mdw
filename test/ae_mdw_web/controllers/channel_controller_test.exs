defmodule AeMdwWeb.ChannelControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs

  import Mock

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
         [fetch!: fn _state, 1 -> %{"hash" => "", "tx" => %{"type" => "ChannelWithdrawTx"}} end]}
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
  end

  test "when no channels, it returns empty data", %{conn: conn, store: store} do
    assert %{"data" => []} =
             conn |> with_store(store) |> get("/v2/channels") |> json_response(200)
  end

  test "when no invalid cursor, it returns error", %{conn: conn, store: store} do
    assert %{"error" => "invalid cursor: foo"} =
             conn |> with_store(store) |> get("/v2/channels", cursor: "foo") |> json_response(400)
  end
end
