defmodule AeMdwWeb.BlockControllerTest do
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
  import Mock

  @blocks_table AeMdwWeb.BlockController.table()
  @default_limit 10
  @blocks_cache_threshold 6

  describe "block" do
    test "get key block by hash", %{conn: conn} do
      kb_hash = "kh_29Gmo8RMdCD5aJ1UUrKd6Kx2c3tvHQu82HKsnVhbprmQnFy5bn"
      bin_kb_hash = AeMdw.Validate.id!(kb_hash)

      with_mocks [
        {:aec_chain, [], get_block: fn ^bin_kb_hash -> {:ok, sample_key_block()} end},
        {:aec_db, [], get_header: fn ^bin_kb_hash -> sample_key_header() end}
      ] do
        conn = get(conn, "/block/#{kb_hash}")

        assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_block(kb_hash) end)
      end
    end

    test "get micro block by hash", %{conn: conn} do
      mb_hash = "mh_RuKG8scokoAdhqNN3uvq29VZBsSaZdpeaoyBsXLeGV69sud85"
      bin_mb_hash = AeMdw.Validate.id!(mb_hash)

      with_mocks [
        {:aec_chain, [], get_block: fn ^bin_mb_hash -> {:ok, sample_micro_block()} end},
        {:aec_db, [], get_header: fn ^bin_mb_hash -> sample_micro_header() end}
      ] do
        conn = get(conn, "/block/#{mb_hash}")

        assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_block(mb_hash) end)
      end
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
    @tag :integration
    test "get key block by key block index(height)", %{conn: conn} do
      kbi = 305_200
      conn = get(conn, "/blocki/#{kbi}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_blocki(conn.params) end)
    end

    @tag :integration
    test "get micro block by given key block index(height) and micro block index", %{conn: conn} do
      kbi = 305_222
      mbi = 3
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 200) == TestUtil.handle_input(fn -> get_blocki(conn.params) end)
    end

    @tag :integration
    test "renders error when key block index is invalid", %{conn: conn} do
      kbi = "invalid"
      conn = get(conn, "/blocki/#{kbi}")

      assert json_response(conn, 400) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end

    @tag :integration
    test "renders error when mickro block index is not present", %{conn: conn} do
      kbi = 305_222
      mbi = 4999
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 404) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end

    @tag :integration
    test "renders error when micro block index is invalid", %{conn: conn} do
      kbi = 305_222
      mbi = "invalid"
      conn = get(conn, "/blocki/#{kbi}/#{mbi}")

      assert json_response(conn, 400) ==
               %{"error" => TestUtil.handle_input(fn -> get_blocki(conn.params) end)}
    end
  end

  describe "blocks" do
    @tag :integration
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

    @tag :integration
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

    @tag :integration
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

    @tag :integration
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

    @tag :integration
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

    @tag :integration
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

    @tag :integration
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

  defp sample_key_block do
    {:key_block, sample_key_header()}
  end

  defp sample_key_header do
    {:key_header, 1,
     <<108, 21, 218, 110, 191, 175, 2, 120, 254, 175, 77, 241, 176, 241, 169, 130, 85, 7, 174,
       123, 154, 73, 75, 195, 76, 145, 113, 63, 56, 221, 87, 131>>,
     <<108, 21, 218, 110, 191, 175, 2, 120, 254, 175, 77, 241, 176, 241, 169, 130, 85, 7, 174,
       123, 154, 73, 75, 195, 76, 145, 113, 63, 56, 221, 87, 131>>,
     <<52, 183, 229, 249, 54, 69, 51, 88, 116, 15, 122, 6, 182, 198, 8, 237, 95, 88, 152, 76, 53,
       115, 239, 229, 75, 84, 120, 17, 7, 73, 153, 49>>, 522_133_279, 7_537_663_592_980_547_537,
     1_543_373_685_748, 1,
     [
       26_922_260,
       37_852_188,
       59_020_115,
       60_279_463,
       79_991_400,
       85_247_410,
       107_259_316,
       109_139_865,
       110_742_806,
       135_064_096,
       135_147_996,
       168_331_414,
       172_261_759,
       199_593_922,
       202_230_201,
       203_701_465,
       210_434_810,
       231_398_482,
       262_809_482,
       271_994_744,
       272_584_245,
       287_928_914,
       292_169_553,
       362_488_698,
       364_101_896,
       364_186_805,
       373_099_116,
       398_793_711,
       400_070_528,
       409_055_423,
       410_928_197,
       423_334_086,
       423_561_843,
       428_130_074,
       496_454_011,
       501_715_005,
       505_858_333,
       514_079_183,
       522_053_501,
       526_239_399,
       527_666_844,
       532_070_334
     ],
     <<109, 80, 187, 72, 39, 0, 181, 159, 179, 75, 226, 70, 33, 153, 149, 169, 59, 82, 131, 166,
       223, 128, 104, 223, 115, 204, 111, 77, 205, 5, 56, 247>>,
     <<186, 203, 214, 163, 246, 107, 124, 137, 222, 135, 217, 193, 221, 104, 215, 16, 94, 25, 47,
       35, 97, 96, 99, 179, 23, 38, 226, 135, 232, 249, 24, 44>>, "",
     %{consensus: :aec_consensus_bitcoin_ng}}
  end

  defp sample_micro_block do
    {:mic_block, sample_micro_header()}
  end

  defp sample_micro_header do
    {:mic_header, 305_488, "",
     <<123, 66, 245, 198, 197, 131, 107, 129, 76, 33, 48, 83, 69, 18, 29, 92, 34, 125, 232, 194,
       72, 143, 41, 63, 18, 139, 120, 116, 45, 79, 16, 108>>,
     <<205, 135, 56, 162, 96, 202, 59, 7, 215, 179, 229, 109, 41, 29, 214, 107, 35, 50, 95, 154,
       219, 228, 142, 169, 53, 232, 166, 4, 232, 147, 188, 64>>,
     <<159, 240, 58, 171, 83, 153, 27, 217, 82, 171, 254, 252, 207, 84, 95, 53, 51, 74, 232, 74,
       71, 119, 195, 119, 76, 151, 185, 56, 200, 189, 193, 78>>,
     <<105, 101, 147, 121, 43, 123, 67, 195, 141, 128, 83, 57, 81, 64, 38, 102, 16, 183, 151, 198,
       70, 31, 124, 51, 136, 54, 61, 145, 175, 206, 242, 131, 139, 7, 85, 12, 93, 191, 223, 205,
       50, 239, 189, 136, 12, 18, 31, 47, 127, 94, 194, 131, 254, 70, 243, 168, 236, 149, 63, 101,
       84, 78, 219, 6>>,
     <<155, 74, 110, 105, 160, 87, 202, 235, 211, 79, 100, 7, 204, 19, 228, 89, 48, 64, 212, 231,
       175, 166, 195, 25, 170, 195, 160, 121, 134, 181, 73, 200>>, 1_598_562_036_727, 4,
     %{consensus: :aec_consensus_bitcoin_ng}}
  end
end
