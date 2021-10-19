defmodule AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdwWeb.BlockchainSim

  import Mock
  import AeMdwWeb.BlockchainSim

  describe "block" do
    test "get key block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000}, b1: {:kb, :alice} do
        %{hash: kb_hash} = blocks[:b1]

        assert %{"hash" => ^kb_hash} = get(conn, "/block/#{kb_hash}") |> json_response(200)
      end
    end

    test "get micro block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        b1: [
          t1: BlockchainSim.spend_tx(:alice, :bob, 5_000)
        ] do
        %{hash: mb_hash} = blocks[:b1]

        assert %{"hash" => ^mb_hash} = get(conn, "/block/#{mb_hash}") |> json_response(200)
      end
    end

    test "renders error when the hash is invalid", %{conn: conn} do
      hash = "kh_NoSuchHash"

      assert %{"error" => <<"invalid id: ", _rest::binary>>} =
               get(conn, "/block/#{hash}") |> json_response(400)
    end
  end
end
