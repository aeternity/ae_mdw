defmodule Integration.AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false
  use Mneme

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil

  require Model

  @moduletag :integration

  @default_limit 10

  describe "block_v1" do
    test "get key block by hash", %{conn: conn} do
      kb_hash = "kh_WLJX9kzQx882vnWg7TuyH4QyMCjdSdz7nXPS9tA9nEwiRnio4"
      conn = get(conn, "/v3/key-blocks/#{kb_hash}")

      auto_assert(
        %{
          "beneficiary" => "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF",
          "beneficiary_reward" => 147_906_567_923_400_000_000,
          "hash" => ^kb_hash,
          "height" => 305_482,
          "info" => "cb_AAACKimwwOc=",
          "micro_blocks_count" => 1,
          "miner" => "ak_2PvNwNrSgF4rvok5DD8RNK71N5Mb6ibVJNYEhJJF4tPzNc9maD",
          "nonce" => 1_767_563_745_050_916,
          "pow" => [
            13_650_272,
            41_606_151,
            53_912_775,
            67_773_119,
            68_620_634,
            71_205_599,
            76_324_383,
            87_000_055,
            95_295_026,
            102_454_695,
            147_564_131,
            149_002_347,
            154_991_926,
            175_421_232,
            200_072_393,
            202_186_175,
            217_037_238,
            217_362_486,
            217_813_784,
            222_258_528,
            224_865_137,
            255_308_070,
            272_068_001,
            275_762_101,
            292_976_255,
            307_553_290,
            320_035_434,
            328_646_446,
            332_428_050,
            341_740_525,
            344_209_924,
            352_363_313,
            372_106_103,
            406_484_514,
            417_551_487,
            439_024_957,
            459_535_743,
            469_876_494,
            471_222_572,
            495_292_518,
            501_024_167,
            501_235_214
          ],
          "prev_hash" => "mh_JqFUL2tHZKhSYLvgD7khwQ1NxCuX4zaJQMY41UMKnjnQumTd8",
          "prev_key_hash" => "kh_o4HN6zayjFXbSFKmiWmin5AciX1oaVgSLHxHcR5QoRTHkqBPj",
          "state_hash" => "bs_bHsr7FHqy1wYukNyhvHxhAQFc63YNBF8iWiJWBQbkj5it7Rdb",
          "target" => 506_133_162,
          "time" => 1_598_560_701_858,
          "transactions_count" => 97,
          "version" => 4
        } <- json_response(conn, 200)
      )
    end

    test "get micro block by hash", %{conn: conn} do
      mb_hash = "mh_RuKG8scokoAdhqNN3uvq29VZBsSaZdpeaoyBsXLeGV69sud85"
      conn = get(conn, "/v3/micro-blocks/#{mb_hash}")

      auto_assert(
        %{
          "hash" => ^mb_hash,
          "height" => 305_488,
          "micro_block_index" => 11,
          "pof_hash" => "no_fraud",
          "prev_hash" => "mh_wHYyBzikXZdkheJ5ydvyWQf86nUHmDwCgb8YrPnJFjv62a7TA",
          "prev_key_hash" => "kh_2ZWwee5FQZ8paq7vntUdK6FjbmYhHNp4gYKbfLVeKd43ZHerYo",
          "signature" =>
            "sg_EnkrpxtKhNgUZJMg3C6QxkigbMo9GE7y6NkSYLHjXZHeiVeWgqpVTjGUByG5aLqToWAV3poyfxN2LHkiTBGAQsUW69Vc7",
          "state_hash" => "bs_2DSQsn4FrR8c6UBnJGqvDnS2ir36KQx6AoCwJLW4Lx2o1oTQfU",
          "time" => 1_598_562_036_727,
          "transactions_count" => 1,
          "txs_hash" => "bx_2BPhEfS6bauk4E1nYdwUg8bB91qwB738kE6zq33vACK9axMW2R",
          "version" => 4
        } <- json_response(conn, 200)
      )
    end

    test "renders error when the hash is invalid", %{conn: conn} do
      hash = "kh_NoSuchHash"
      conn = get(conn, "/v3/key-blocks/#{hash}")

      assert json_response(conn, 400) == %{
               "error" => "invalid hash: #{hash}"
             }
    end
  end

  describe "blocki" do
    test "get key block by key block index(height)", %{conn: conn} do
      kbi = 305_200
      conn = get(conn, "/v3/key-blocks/#{kbi}")

      auto_assert(
        %{
          "beneficiary" => "ak_542o93BKHiANzqNaFj6UurrJuDuxU61zCGr9LJCwtTUg34kWt",
          "beneficiary_reward" => 148_797_103_356_000_000_000,
          "hash" => "kh_aax5VWAHTFMjpReDvNHUge7oMEJxKpE5vq3WSNoxkcq2Xgsu5",
          "height" => ^kbi,
          "info" => "cb_AAACKimwwOc=",
          "micro_blocks_count" => 56,
          "miner" => "ak_2v9a3Rt6pvvaTAqhzDz79s7GAowR4DZtmvVX1ZnZpCfRbinAVz",
          "nonce" => 4_915_859_620_130,
          "pow" => [
            6_255_147,
            14_881_492,
            51_277_186,
            68_697_862,
            71_408_501,
            76_289_614,
            81_364_924,
            84_542_169,
            85_923_381,
            92_249_566,
            94_260_268,
            102_676_800,
            112_282_167,
            149_376_499,
            168_080_352,
            196_450_080,
            202_128_968,
            203_632_458,
            222_271_015,
            238_070_324,
            259_532_158,
            284_183_385,
            289_603_858,
            292_358_998,
            336_154_548,
            349_487_851,
            352_621_908,
            393_092_461,
            408_579_093,
            411_222_239,
            421_173_462,
            461_007_413,
            486_631_607,
            487_554_937,
            491_693_061,
            496_786_335,
            498_505_457,
            508_575_650,
            512_540_019,
            516_927_030,
            517_946_121,
            532_018_257
          ],
          "prev_hash" => "mh_26eF6kyZqJxHrApTLHewDibpwDtmyqxfPaVVpC9NQKm6cWEGku",
          "prev_key_hash" => "kh_2ddwKd74DQkYSYXrPhqCYNnG47JqWJgZUPiGp4DJKHFRTa9VKF",
          "state_hash" => "bs_jtNGNBxkaD2j2Z7EDZFwKkz3yMcEzKCHWSKvPBdRcHAomHpj5",
          "target" => 506_058_045,
          "time" => 1_598_509_187_554,
          "transactions_count" => 83,
          "version" => 4
        } <- json_response(conn, 200)
      )
    end

    test "get micro block by given key block index(height) and micro block index", %{conn: conn} do
      kbi = 305_222
      mbi = 3
      conn = get(conn, "/v2/blocks/#{kbi}/#{mbi}")

      auto_assert(
        %{
          "hash" => "mh_SidHcZxja5FMYKLTf2gkhSZvLvoWkugck1NXZp2T7yzxeewQk",
          "height" => ^kbi,
          "pof_hash" => "no_fraud",
          "prev_hash" => "mh_2uTHJ6AFFK2WicxKK26EPiS8ZD8gJfE6n22JspwVLFdZQsBSFU",
          "prev_key_hash" => "kh_2KCrF171GcHiv7a4EZCYXkpuwppqQBUrNZpTZYjU2Gy5mVWTzu",
          "signature" =>
            "sg_DWwimBvGRDckm4zcdRmckHierekqKMePiWbnFnBQKDH36shzFJR288pA7SYB1wSfSV4WivZxkNSGeVdRC3WmtZ55KuP3m",
          "state_hash" => "bs_zLCQ5W4uQgrPc8XVJbGUhSmMZvkcxTTwtyg9757TCVik7RxkH",
          "time" => 1_598_513_060_178,
          "txs_hash" => "bx_rs2yKJHpwADFgjuogFvSpcqYXSy6WjcN7Xw45rJLNCrrwtELB",
          "version" => 4
        } <- json_response(conn, 200)
      )
    end

    test "renders error when key block index is invalid", %{conn: conn} do
      kbi = "invalid"
      conn = get(conn, "/v3/key-blocks/#{kbi}")

      auto_assert(%{"error" => "invalid hash: invalid"} <- json_response(conn, 400))
    end

    test "renders error when mickro block index is not present", %{conn: conn} do
      kbi = 305_222
      mbi = 4999
      conn = get(conn, "/v2/blocks/#{kbi}/#{mbi}")

      auto_assert(%{"error" => "not found: {305222, 4999}"} <- json_response(conn, 404))
    end

    test "renders error when micro block index is invalid", %{conn: conn} do
      kbi = 305_222
      mbi = "invalid"
      conn = get(conn, "/v2/blocks/#{kbi}/#{mbi}")

      auto_assert(%{"error" => "invalid block index: 305222/invalid"} <- json_response(conn, 400))
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
      last_gen = DbUtil.last_gen!(state)

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

      auto_assert(
        %{"error" => "not found: kh_2bXDk3CW3qfFSriMtaFnQUKvNr4wNFZn3tPpRLmKCse4jHmt5U"} <-
          conn |> get("/v3/key-blocks/#{hash}") |> json_response(404)
      )
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
end
