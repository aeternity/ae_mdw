defmodule AeMdwWeb.Plugs.RequestSpanTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Validate

  import Mock
  import AeMdwWeb.BlockchainSim

  require Model

  describe "call/2" do
    @http_request_event [:ae_mdw, :http, :request]
    @phoenix_endpoint_event [:phoenix, :endpoint, :stop]

    @events [@http_request_event, @phoenix_endpoint_event]

    setup context do
      :telemetry.attach_many(context.test, @events, &__MODULE__.message_pid/4, self())
    end

    # credo:disable-for-next-line
    def message_pid(event, measures, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, {measures, metadata}})
    end

    test "emits duration on endpoint send", %{conn: conn, store: store} do
      with_blockchain %{}, kb1: [] do
        %{hash: kb_hash, height: kbi} = blocks[:kb1]

        store =
          Store.put(
            store,
            Model.Block,
            Model.block(index: {kbi, -1}, hash: Validate.id!(kb_hash))
          )

        _response =
          conn |> with_store(store) |> get("/v2/blocks/#{kb_hash}") |> json_response(200)

        assert_received {:telemetry_event, [:ae_mdw, :http, :request],
                         {%{duration: _duration},
                          %{route: "/v2/blocks/:hash_or_kbi", request_id: _req_id}}}

        refute_received {:telemetry_event, [:phoenix, :endpoint, :stop],
                         {%{duration: _duration}, %{route: _route}}}

        assert_received {:telemetry_event, [:phoenix, :endpoint, :stop],
                         {%{duration: _duration}, _metadata}}
      end
    end
  end
end
