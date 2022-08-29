defmodule AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Validate
  alias AeMdwWeb.BlockchainSim

  import Mock
  import AeMdwWeb.BlockchainSim
  import AeMdwWeb.Helpers.AexnHelper, only: [enc_block: 2]

  require Model

  describe "blocks" do
    test "get key block by hash", %{conn: conn, store: store} do
      with_blockchain %{}, kb1: [] do
        %{hash: kb_hash, height: kbi} = blocks[:kb1]

        store =
          Store.put(
            store,
            Model.Block,
            Model.block(index: {kbi, -1}, hash: Validate.id!(kb_hash))
          )

        assert response_data =
                 %{"hash" => ^kb_hash} =
                 conn |> with_store(store) |> get("/v2/blocks/#{kb_hash}") |> json_response(200)

        refute Map.has_key?(response_data, "micro_blocks")
      end
    end

    test "get microblock by hash", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: BlockchainSim.spend_tx(:alice, :bob, 5_000)
        ] do
        %{hash: mb_hash, height: kbi} = blocks[:mb1]

        store =
          Store.put(
            store,
            Model.Block,
            Model.block(index: {kbi, 0}, hash: Validate.id!(mb_hash))
          )

        assert response_data =
                 %{"hash" => ^mb_hash} =
                 conn |> with_store(store) |> get("/v2/blocks/#{mb_hash}") |> json_response(200)

        refute Map.has_key?(response_data, "micro_blocks")
      end
    end

    test "get generation blocks with microblocks", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        kb1: [
          mb1: [
            t1: BlockchainSim.spend_tx(:alice, :bob, 5_000)
          ],
          mb2: [
            t2: BlockchainSim.spend_tx(:bob, :alice, 3_000)
          ]
        ] do
        %{hash: kb1_hash, height: kbi} = blocks[:kb1]
        %{hash: mb1_hash, time: mb_time1} = blocks[:mb1]
        %{hash: mb2_hash, time: mb_time2} = blocks[:mb2]

        store =
          store
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, -1}, hash: Validate.id!(kb1_hash))
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, 0}, hash: Validate.id!(mb1_hash))
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, 1}, hash: Validate.id!(mb2_hash))
          )

        assert %{"hash" => ^kb1_hash, "micro_blocks" => mbs} =
                 conn |> with_store(store) |> get("/v2/blocks/#{kbi}") |> json_response(200)

        assert [
                 %{"hash" => ^mb1_hash, "time" => ^mb_time1},
                 %{"hash" => ^mb2_hash, "time" => ^mb_time2}
               ] = mbs

        assert mbs == Enum.sort_by(mbs, & &1["time"]) and mb_time1 != 0 and mb_time2 != 0
      end
    end

    test "renders bad request when the hash is invalid", %{conn: conn} do
      hash = "kh_InvalidHash"
      error_msg = "invalid id: #{hash}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/blocks/#{hash}") |> json_response(400)
    end

    test "renders not found when hash is unknown", %{conn: conn} do
      unknown_kb_hash = enc_block(:key, :crypto.strong_rand_bytes(32))
      error_msg = "not found: #{unknown_kb_hash}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/blocks/#{unknown_kb_hash}") |> json_response(404)
    end

    test "renders not found when height is unknown", %{conn: conn} do
      unknown_height = Enum.random(100_000..999_999)
      error_msg = "not found: #{unknown_height}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/blocks/#{unknown_height}") |> json_response(404)
    end
  end

  describe "block_v1" do
    test "get key block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000}, b1: [] do
        %{hash: kb_hash} = blocks[:b1]

        assert %{"hash" => ^kb_hash} = conn |> get("/block/#{kb_hash}") |> json_response(200)
      end
    end

    test "get micro block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: BlockchainSim.spend_tx(:alice, :bob, 5_000)
        ] do
        %{hash: mb_hash} = blocks[:mb1]

        assert %{"hash" => ^mb_hash} = conn |> get("/block/#{mb_hash}") |> json_response(200)
      end
    end

    test "renders bad request when the hash is invalid", %{conn: conn} do
      hash = "kh_InvalidHash"
      error_msg = "invalid id: #{hash}"
      assert %{"error" => ^error_msg} = conn |> get("/block/#{hash}") |> json_response(400)
    end
  end
end
