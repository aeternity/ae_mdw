defmodule Integration.AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db
  alias AeMdw.TestUtil
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  @moduletag :integration

  @default_limit 10

  describe "block_v1" do
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
    test "when direction=forward it gets generations starting from 0", %{conn: conn} do
      direction = "forward"

      assert %{"data" => blocks, "next" => next_url} =
               conn |> get("/blocks/#{direction}") |> json_response(200)

      assert @default_limit = length(blocks)

      assert blocks
             |> Enum.with_index()
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => next_blocks, "prev" => prev_url} =
               conn |> get(next_url) |> json_response(200)

      assert @default_limit = length(next_blocks)

      assert next_blocks
             |> Enum.zip(10..19)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => ^blocks} = conn |> get(prev_url) |> json_response(200)
    end

    test "when direction=backward it gets generations backwards", %{conn: conn} do
      state = State.new()
      direction = "backward"
      limit = 3
      last_gen = DbUtil.last_gen(state)

      assert %{"data" => blocks, "next" => next_url} =
               conn |> get("/blocks/#{direction}?limit=#{limit}") |> json_response(200)

      assert ^limit = length(blocks)

      assert blocks
             |> Enum.zip(last_gen..(last_gen - 2))
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => next_blocks, "prev" => prev_url} =
               conn |> get(next_url) |> json_response(200)

      assert ^limit = length(next_blocks)

      assert next_blocks
             |> Enum.zip((last_gen - 3)..(last_gen - 5))
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => ^blocks} = conn |> get(prev_url) |> json_response(200)
    end

    test "it gets generations with numeric range and default limit", %{conn: conn} do
      range = "305000-305100"

      assert %{"data" => blocks, "next" => next_url} =
               conn |> get("/blocks/#{range}") |> json_response(200)

      assert @default_limit = length(blocks)

      assert blocks
             |> Enum.zip(305_000..305_100)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => next_blocks, "prev" => prev_url} =
               conn |> get(next_url) |> json_response(200)

      assert @default_limit = length(next_blocks)

      assert next_blocks
             |> Enum.zip(305_010..305_100)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => ^blocks} = conn |> get(prev_url) |> json_response(200)
    end

    test "it gets generations with numeric range and limit=1", %{conn: conn} do
      range = "305000-305100"
      limit = 1

      assert %{"data" => blocks, "next" => next_url} =
               conn |> get("/blocks/#{range}?limit=#{limit}") |> json_response(200)

      assert ^limit = length(blocks)

      assert blocks
             |> Enum.zip(305_000..305_100)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => next_blocks, "prev" => prev_url} =
               conn |> get(next_url) |> json_response(200)

      assert ^limit = length(next_blocks)

      assert next_blocks
             |> Enum.zip(305_001..305_100)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      assert %{"data" => ^blocks} = conn |> get(prev_url) |> json_response(200)
    end

    test "get blocks and sorted microblocks in a single generation", %{conn: conn} do
      range = "471542-471542"
      count = 1
      conn = get(conn, "/v2/blocks", scope: "gen:#{range}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == count

      Enum.each(response["data"], fn %{"micro_blocks" => mbs} ->
        assert mbs == Enum.sort_by(mbs, fn %{"time" => time} -> time end)
      end)

      assert is_nil(response["next"])
    end

    test "get blocks and sorted microblocks in multiple generations", %{conn: conn} do
      range = "471542-471563"
      limit = 10
      conn = get(conn, "/v2/blocks", scope: "gen:#{range}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == limit

      Enum.each(response["data"], fn %{"micro_blocks" => mbs} ->
        assert mbs == Enum.sort_by(mbs, fn %{"time" => time} -> time end)
      end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == limit
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      conn = get(conn, "/v2/blocks", scope: "gen:#{range}")

      assert json_response(conn, 400) ==
               %{"error" => "invalid range: #{range}"}
    end

    test "when block is not found, it returns a 404 error message", %{conn: conn} do
      hash = "kh_2bXDk3CW3qfFSriMtaFnQUKvNr4wNFZn3tPpRLmKCse4jHmt5U"
      error_msg = "not found: #{hash}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/blocks/#{hash}") |> json_response(404)
    end
  end

  describe "block" do
    test "gets blocks by height and encodes without erroring", %{conn: conn} do
      height = 444_851

      assert %{"height" => ^height} =
               conn
               |> get("/v2/blocks/#{height}")
               |> json_response(200)
    end
  end

  ################

  defp get_block(enc_block_hash) when is_binary(enc_block_hash) do
    block_hash = Validate.id!(enc_block_hash)

    case :aec_chain.get_block(block_hash) do
      {:ok, _block} ->
        header = :aec_db.get_header(block_hash)

        :aec_headers.serialize_for_client(header, Db.prev_block_type(header))

      :error ->
        raise ErrInput.NotFound, value: enc_block_hash
    end
  end

  defp get_block({_, mbi} = block_index) do
    state = State.new()

    case State.get(state, Model.Block, block_index) do
      {:ok, block} ->
        type = (mbi == -1 && :key_block_hash) || :micro_block_hash
        hash = Model.block(block, :hash)
        get_block(Enc.encode(type, hash))

      :not_found ->
        raise ErrInput.NotFound, value: block_index
    end
  end

  defp get_blocki(%{"kbi" => kbi} = req) do
    mbi = Map.get(req, "mbi", "-1")

    (kbi <> "/" <> mbi)
    |> Validate.block_index()
    |> then(fn {:ok, bi} ->
      get_block(bi)
    end)
  end
end
