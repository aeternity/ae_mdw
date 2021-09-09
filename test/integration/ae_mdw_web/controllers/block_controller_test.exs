defmodule Integration.AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.{Model, Format}
  alias AeMdwWeb.{BlockController, TestUtil}
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.EtsCache
  require Model

  import AeMdw.Db.Util

  @moduletag :integration

  @blocks_table AeMdwWeb.BlockController.table()
  @default_limit 10
  @blocks_cache_threshold 6

  describe "block" do
    test "get key block by hash", %{conn: conn} do
      kb_hash = "kh_WLJX9kzQx882vnWg7TuyH4QyMCjdSdz7nXPS9tA9nEwiRnio4"
      conn = get(conn, "/block/#{kb_hash}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_block(kb_hash) end)
    end

    test "get micro block by hash", %{conn: conn} do
      mb_hash = "mh_RuKG8scokoAdhqNN3uvq29VZBsSaZdpeaoyBsXLeGV69sud85"
      conn = get(conn, "/block/#{mb_hash}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_block(mb_hash) end)
    end

    test "renders error when the hash is invalid", %{conn: conn} do
      hash = "kh_NoSuchHash"
      conn = get(conn, "/block/#{hash}")

      assert json_response(conn, 400) == %{
               "error" => TestUtil.handle_input(fn -> get_block(hash) end)
             }
    end
  end

  describe "blocki" do
    test "get key block by key block index(height)", %{conn: conn} do
      kbi = 305_200
      conn = get(conn, "/blocki/#{kbi}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_blocki(conn.params) end)
    end

    test "get micro block by given key block index(height) and micro block index", %{conn: conn} do
      kbi = 305_222
      mbi = 3
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_blocki(conn.params) end)
    end

    test "renders error when key block index is invalid", %{conn: conn} do
      kbi = "invalid"
      conn = get(conn, "/blocki/#{kbi}")

      assert json_response(conn, 400) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end

    test "renders error when mickro block index is not present", %{conn: conn} do
      kbi = 305_222
      mbi = 4999
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 404) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end

    test "renders error when micro block index is invalid", %{conn: conn} do
      kbi = 305_222
      mbi = "invalid"
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 400) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end
  end

  describe "blocks" do
    test "get generations when direction=forward and default limit", %{conn: conn} do
      direction = "forward"
      conn = get(conn, "/blocks/#{direction}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get generations when direction=backward and limit=3", %{conn: conn} do
      direction = "backward"
      limit = 3
      conn = get(conn, "/blocks/#{direction}?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get generations with numeric range and default limit", %{conn: conn} do
      range = "305000-305100"
      conn = get(conn, "/blocks/#{range}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get generations with numeric range and limit=1", %{conn: conn} do
      range = "305000-305100"
      limit = 1
      conn = get(conn, "/blocks/#{range}?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get uncached generations with range", %{conn: conn} do
      range_begin = last_gen() - @blocks_cache_threshold + 1
      range_end = last_gen()
      range = "#{range_begin}-#{range_end}"
      limit = @blocks_cache_threshold
      conn = get(conn, "/blocks/#{range}?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
      assert nil == EtsCache.get(@blocks_table, range_begin)
      assert nil == EtsCache.get(@blocks_table, range_end)

      # assert there's nothing next
      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.empty?(response_next["data"])
    end

    test "get a mix of uncached and cached generations with range", %{conn: conn} do
      remaining = 3
      range_begin = last_gen() - @blocks_cache_threshold + 1 - remaining
      range_end = last_gen()
      range = "#{range_begin}-#{range_end}"
      limit = @blocks_cache_threshold

      conn = get(conn, "/blocks/#{range}?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
      assert {%{"height" => ^range_begin}, _} = EtsCache.get(@blocks_table, range_begin)
      assert nil == EtsCache.get(@blocks_table, range_end)
      assert nil == EtsCache.get(@blocks_table, range_end - @blocks_cache_threshold + 1)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks, %{}, conn.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == remaining
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get blocks and sorted microblocks in a single generation", %{conn: conn} do
      range = "471542-471542"
      count = 1
      conn = get(conn, "/v2/blocks/#{range}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == count

      Enum.each(response["data"], fn %{"micro_blocks" => mbs} ->
        assert mbs == Enum.sort_by(mbs, fn %{"time" => time} -> time end)
      end)

      assert nil == response["next"]
    end

    test "get blocks and sorted microblocks in multiple generations", %{conn: conn} do
      range = "471542-471563"
      limit = 10
      conn = get(conn, "/v2/blocks/#{range}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == limit

      Enum.each(response["data"], fn %{"micro_blocks" => mbs} ->
        assert mbs == Enum.sort_by(mbs, fn %{"time" => time} -> time end)
      end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {BlockController, :blocks_v2, %{}, conn.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      conn = get(conn, "/blocks/#{range}")

      assert json_response(conn, 400) ==
               %{"error" => "invalid range: #{range}"}
    end
  end

  ################

  defp get_block(enc_block_hash) when is_binary(enc_block_hash) do
    block_hash = Validate.id!(enc_block_hash)

    case :aec_chain.get_block(block_hash) do
      {:ok, _} ->
        Format.to_map({:block, {nil, nil}, nil, block_hash})

      :error ->
        raise ErrInput.NotFound, value: enc_block_hash
    end
  end

  defp get_block({_, mbi} = block_index) do
    case read_block(block_index) do
      [block] ->
        type = (mbi == -1 && :key_block_hash) || :micro_block_hash
        hash = Model.block(block, :hash)
        get_block(Enc.encode(type, hash))

      [] ->
        raise ErrInput.NotFound, value: block_index
    end
  end

  defp get_blocki(%{"kbi" => kbi} = req) do
    mbi = Map.get(req, "mbi", "-1")

    (kbi <> "/" <> mbi)
    |> Validate.block_index!()
    |> get_block()
  end
end
