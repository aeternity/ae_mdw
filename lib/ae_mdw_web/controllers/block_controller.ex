defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.{Model, Format}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.EtsCache
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.SwaggerParameters
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  @tab __MODULE__
  ##########

  def table(), do: @tab

  def stream_plug_hook(%Plug.Conn{path_info: ["blocks" | rem], params: params} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    scope_info =
      case rem do
        [x | _] when x in ["forward", "backward"] -> rem
        _ -> ensure_prefix("gen", rem)
      end

    P.handle_assign(
      conn,
      P.parse_scope(scope_info, ["gen"]),
      P.parse_offset(params),
      {:ok, %{}}
    )
  end

  ##########

  def block(conn, %{"hash" => hash}),
    do: handle_input(conn, fn -> block_reply(conn, hash) end)

  def blocki(conn, %{"kbi" => kbi} = req),
    do:
      handle_input(conn, fn ->
        mbi = Map.get(req, "mbi", "-1")
        block_reply(conn, Validate.block_index!(kbi <> "/" <> mbi))
      end)

  def blocks(conn, _req),
    do: Cont.response(conn, &json/2)

  ##########

  def db_stream(:blocks, _params, {:gen, range}),
    do: Stream.map(range, &generation(&1, last_gen()))

  ##########

  def generation(height, last_gen),
    do: generation(block_jsons(height, last_gen))

  ##########
  # def generation([kb_json | mb_jsons]) do
  #   mb_jsons =
  #     for %{"hash" => mb_hash} = mb_json <- mb_jsons, reduce: %{} do
  #       mbs ->
  #         micro = :aec_db.get_block(Validate.id!(mb_hash))
  #         header = :aec_blocks.to_header(micro)

  #         txs_json =
  #           for tx <- :aec_blocks.txs(micro), reduce: %{} do
  #             txs ->
  #               %{"hash" => tx_hash} = tx_json = :aetx_sign.serialize_for_client(header, tx)
  #               Map.put(txs, tx_hash, tx_json)
  #           end

  #         mb_json = Map.put(mb_json, "transactions", txs_json)
  #         Map.put(mbs, mb_hash, mb_json)
  #     end

  #   Map.put(kb_json, "micro_blocks", mb_jsons)
  # end

  ##########
  def generation([kb_json | mb_jsons]) do
    # Add checks for cache
    height = kb_json["height"]

    case EtsCache.get(@tab, height) do
      {kb_json, _indx} ->
        kb_json

      nil ->
        mb_jsons =
          for %{"hash" => mb_hash} = mb_json <- mb_jsons, reduce: %{} do
            mbs ->
              micro = :aec_db.get_block(Validate.id!(mb_hash))
              header = :aec_blocks.to_header(micro)

              txs_json =
                for tx <- :aec_blocks.txs(micro), reduce: %{} do
                  txs ->
                    %{"hash" => tx_hash} = tx_json = :aetx_sign.serialize_for_client(header, tx)
                    Map.put(txs, tx_hash, tx_json)
                end

              mb_json = Map.put(mb_json, "transactions", txs_json)
              Map.put(mbs, mb_hash, mb_json)
          end

        Map.put(kb_json, "micro_blocks", mb_jsons)
        EtsCache.put(@tab, height, kb_json)
        kb_json
    end
  end

  def block_jsons(height, last_gen) when height < last_gen do
    collect_keys(Model.Block, [], {height, <<>>}, &prev/2, fn
      {^height, _} = k, acc ->
        {:cont, [Format.to_map(read_block!(k)) | acc]}

      _k, acc ->
        {:halt, acc}
    end)
  end

  def block_jsons(last_gen, last_gen) do
    {:ok, %{key_block: kb, micro_blocks: mbs}} = :aec_chain.get_current_generation()
    ^last_gen = :aec_blocks.height(kb)

    for block <- [kb | mbs] do
      header = :aec_blocks.to_header(block)
      :aec_headers.serialize_for_client(header, prev_block_type(header))
    end
  end

  ##########

  def block_reply(conn, enc_block_hash) when is_binary(enc_block_hash) do
    block_hash = Validate.id!(enc_block_hash)

    case :aec_chain.get_block(block_hash) do
      {:ok, _} ->
        # note: the `nil` here - for json formatting, we reuse AE node code
        json(conn, Format.to_map({:block, {nil, nil}, nil, block_hash}))

      :error ->
        raise ErrInput.NotFound, value: enc_block_hash
    end
  end

  def block_reply(conn, {_, mbi} = block_index) do
    case read_block(block_index) do
      [block] ->
        type = (mbi == -1 && :key_block_hash) || :micro_block_hash
        hash = Model.block(block, :hash)
        block_reply(conn, Enc.encode(type, hash))

      [] ->
        raise ErrInput.NotFound, value: block_index
    end
  end

  ########
  def swagger_definitions do
    %{
      BlockResponse:
        swagger_schema do
          title("Block")
          description("Response schema for block information")

          properties do
            beneficiary(:string, "The beneficiary", required: false)
            hash(:string, "The block hash", required: true)
            height(:integer, "The block height", required: true)
            pof_hash(:string, "The pof hash", required: false)
            info(:string, "The info", required: false)
            miner(:string, "The miner public key", required: false)
            nonce(:string, "The nonce", required: false)
            pow(:array, "The pow", required: false)
            prev_hash(:string, "The previous block hash", required: true)
            prev_key_hash(:string, "The previous key block hash", required: true)
            signature(:string, "The signature", required: false)
            state_hash(:string, "The state hash", required: true)
            target(:integer, "The target", required: false)
            time(:integer, "The time", required: false)
            txs_hash(:string, "The txs hash", required: false)
            version(:integer, "The version", required: true)
          end

          example(%{
            beneficiary: "ak_2MR38Zf355m6JtP13T3WEcUcSLVLCxjGvjk6zG95S2mfKohcSS",
            hash: "kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6",
            height: 123_008,
            info: "cb_AAAAAfy4hFE=",
            miner: "ak_Fqnmm5hRAMaVPWk8wzpodMopZgWghMns4mM7kSV1jgT89p9AV",
            nonce: 9_223_756_548_132_685_562,
            pow: [
              12_359_907,
              21_243_613,
              31_370_838,
              34_911_479,
              39_070_315,
              39_375_528,
              45_751_339,
              49_864_206,
              56_785_423,
              70_282_271,
              89_781_776,
              136_985_196,
              140_580_763,
              142_415_353,
              145_306_210,
              148_449_813,
              156_037_609,
              161_568_067,
              170_308_922,
              185_345_129,
              192_805_579,
              214_115_188,
              220_339_679,
              243_288_723,
              258_891_016,
              283_001_743,
              284_306_909,
              286_457_285,
              326_405_486,
              352_963_232,
              377_904_500,
              378_120_539,
              380_987_399,
              388_675_008,
              447_958_786,
              457_602_498,
              465_751_225,
              466_823_982,
              475_416_389,
              491_255_227,
              530_197_445,
              533_633_643
            ],
            prev_hash: "kh_hwin2p8u87mqiK836FixGa1pL9eBkL1Ju37Yi6EUebCgAf8rm",
            prev_key_hash: "kh_hwin2p8u87mqiK836FixGa1pL9eBkL1Ju37Yi6EUebCgAf8rm",
            state_hash: "bs_9Dg6mTmiJLpbg9dzgjnNFVidQesvZYZG3dEviUCd4oE1hUcna",
            target: 504_082_055,
            time: 1_565_548_832_164,
            version: 3
          })
        end,
      BlocksResponse:
        swagger_schema do
          title("Blocks")
          description("Response schema for multiple generations")

          properties do
            data(:array, "The data for the multiple generations", required: true)
            next(:string, "The continuation link", required: true, nullable: true)
          end

          example(%{
            data: [
              %{
                beneficiary: "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
                hash: "kh_22BuVBCFvW5FvQu3F8h4v351SfJPokR9ytwAD77Lyuo6mqxeeF",
                height: 300_111,
                info: "cb_AAACKbJ2LDk=",
                micro_blocks: %{
                  mh_2iTJfCVYbtawdrdYr8sCAwLbJe26Wf8T6UhH7aSfQEYVHeLtsq: %{
                    hash: "mh_2iTJfCVYbtawdrdYr8sCAwLbJe26Wf8T6UhH7aSfQEYVHeLtsq",
                    height: 300_111,
                    pof_hash: "no_fraud",
                    prev_hash: "kh_22BuVBCFvW5FvQu3F8h4v351SfJPokR9ytwAD77Lyuo6mqxeeF",
                    prev_key_hash: "kh_22BuVBCFvW5FvQu3F8h4v351SfJPokR9ytwAD77Lyuo6mqxeeF",
                    signature:
                      "sg_8fAjbD1LXofZBennTDFwtrnbJC4CnCLZVjuRYemjWNMwaHiLE5ATdcALTuq3NTjzhZMtXZcMtpw54FrbghksnRPsHr4je",
                    state_hash: "bs_Ryc28k53YEkZJAjGL7hQQ6ndQjnsUdPAyHwYDEQhAFWBGYEGK",
                    time: 1_597_586_941_797,
                    transactions: %{
                      th_24eC98mwqVfHNpVwMwMy89BL2nrerLxfD5eGKDfsBUkSavWWMf: %{
                        block_hash: "mh_2iTJfCVYbtawdrdYr8sCAwLbJe26Wf8T6UhH7aSfQEYVHeLtsq",
                        block_height: 300_111,
                        hash: "th_24eC98mwqVfHNpVwMwMy89BL2nrerLxfD5eGKDfsBUkSavWWMf",
                        signatures: [
                          "sg_QCdArmCTBCvm6SRTqBJfydunNSw5M6civ5pn7qmvrtS5Y1f12zdwiyQMFaN14EVKhrbfURGvzoZH2prwathvQNcoQ11Uy"
                        ],
                        tx: %{
                          amount: 20000,
                          fee: 19_340_000_000_000,
                          nonce: 2_883_842,
                          payload:
                            "ba_MzAwMTEwOmtoXzJBS2gxc0hueVFUd1JpVmRBY3dQcWc1R0xQUmEyRlBYUjdYZ2RiWm9MUFRqZ3ZxdVpGOm1oXzJVbUY2RjFLVnhSc3ZLNWRFb0tndGZoeFQ2a3p5M0x0THdmTmJOQTR5QUxRVUoyNEZlOjE1OTc1ODY5MzPaWF/X",
                          recipient_id: "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
                          sender_id: "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
                          ttl: 300_120,
                          type: "SpendTx",
                          version: 1
                        }
                      },
                      th_27p5PC2JGzm5L5MXUEPSoEZGEGWe2YHxbnp6TAVpdWFgRcN1Kk: %{
                        block_hash: "mh_2iTJfCVYbtawdrdYr8sCAwLbJe26Wf8T6UhH7aSfQEYVHeLtsq",
                        block_height: 300_111,
                        hash: "th_27p5PC2JGzm5L5MXUEPSoEZGEGWe2YHxbnp6TAVpdWFgRcN1Kk",
                        signatures: [
                          "sg_Cr6awb2Wgi9h9BbenWkdc8r2r2Gfpvsuu5VqX4iJMnpxZMGtSk1JwXiwBunvssMHg1b5w4JpVyUYT8kcQfRTChVJpeFvq"
                        ],
                        tx: %{
                          amount: 20000,
                          fee: 19_320_000_000_000,
                          nonce: 2_884_619,
                          payload:
                            "ba_MzAwMTEwOmtoXzJBS2gxc0hueVFUd1JpVmRBY3dQcWc1R0xQUmEyRlBYUjdYZ2RiWm9MUFRqZ3ZxdVpGOm1oX1JBaldveUw4enVBZmczZlBtUXk0YlFIaXJVQUVHVGVlNmR0Q0ZyVHR6OURxazJGdjc6MTU5NzU4NjkzN20RnXs=",
                          recipient_id: "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq",
                          sender_id: "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq",
                          ttl: 300_120,
                          type: "SpendTx",
                          version: 1
                        }
                      },
                      th_2HNH4euVw13H5zq5f8EBAU2qL1zAYFDRZz7KZVmotoSd4KurK2: %{
                        block_hash: "mh_2iTJfCVYbtawdrdYr8sCAwLbJe26Wf8T6UhH7aSfQEYVHeLtsq",
                        block_height: 300_111,
                        hash: "th_2HNH4euVw13H5zq5f8EBAU2qL1zAYFDRZz7KZVmotoSd4KurK2",
                        signatures: [
                          "sg_5qYU16V7FUmUVc7ct3Zaz2mcbfRPvy4u9TjQaSwKc1aT9hbSNYznQLnvn4NJ4QoA7ZxaQ97GDYvz6G1xCPnKj2DnSwyh7"
                        ],
                        tx: %{
                          amount: 20000,
                          fee: 19_320_000_000_000,
                          nonce: 2_884_573,
                          payload:
                            "ba_MzAwMTEwOmtoXzJBS2gxc0hueVFUd1JpVmRBY3dQcWc1R0xQUmEyRlBYUjdYZ2RiWm9MUFRqZ3ZxdVpGOm1oX1JBaldveUw4enVBZmczZlBtUXk0YlFIaXJVQUVHVGVlNmR0Q0ZyVHR6OURxazJGdjc6MTU5NzU4NjkzNjtuoqw=",
                          recipient_id: "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
                          sender_id: "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
                          ttl: 300_120,
                          type: "SpendTx",
                          version: 1
                        }
                      }
                    },
                    txs_hash: "bx_VCPWd8hkrDhL922ZqJDVsmzQUv2Mommr5xStCGpRpmYCtxYn4",
                    version: 4
                  }
                },
                miner: "ak_wGQ59uKFAqAgkQHr3NBWFud1TNZJeS4YgRrpexe7pmqxBrg6t",
                nonce: 18_429_171_940_868_612_898,
                pow: [
                  768_191,
                  11_634_428,
                  12_436_610,
                  28_959_995,
                  31_538_410,
                  44_136_935,
                  50_232_943,
                  84_540_411,
                  94_716_421,
                  106_227_445,
                  141_460_600,
                  148_446_520,
                  157_095_206,
                  192_242_339,
                  207_514_671,
                  229_105_874,
                  230_039_137,
                  230_066_004,
                  234_245_150,
                  240_470_674,
                  251_347_269,
                  275_059_442,
                  296_636_962,
                  310_281_198,
                  314_699_295,
                  316_539_758,
                  324_051_349,
                  338_239_987,
                  341_080_503,
                  344_857_362,
                  361_046_795,
                  362_110_238,
                  378_985_679,
                  402_618_476,
                  408_531_046,
                  414_403_747,
                  441_213_420,
                  441_693_933,
                  444_683_146,
                  450_052_150,
                  516_140_379,
                  528_676_885
                ],
                prev_hash: "mh_2UmF6F1KVxRsvK5dEoKgtfhxT6kzy3LtLwfNbNA4yALQUJ24Fe",
                prev_key_hash: "kh_2AKh1sHnyQTwRiVdAcwPqg5GLPRa2FPXR7XgdbZoLPTjgvquZF",
                state_hash: "bs_2okaX1hWaV47fdnXsJS2crvegdZBoYDh4GQ12EPhu5R9idb4Ue",
                target: 508_388_341,
                time: 1_597_586_932_827,
                version: 4
              }
            ],
            next: "blocks/gen/300111-300300?limit=1&page=2"
          })
        end
    }
  end

  swagger_path :block do
    get("/block/{hash}")
    description("Get block information by given key/micro block hash.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_hash")
    tag("Middleware")

    parameters do
      hash(:path, :string, "The key/micro block hash",
        required: true,
        example: "kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6"
      )
    end

    response(
      200,
      "Returns block information by given key/micro block hash",
      Schema.ref(:BlockResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :blocks do
    get("/blocks/{range_or_dir}")
    description("Get multiple generations.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_blocks")
    tag("Middleware")
    SwaggerParameters.limit_and_page_params()

    parameters do
      range_or_dir(
        :path,
        :string,
        "The direction, which could be **forward** or **backward**, or non-negative integer range",
        required: true,
        example: "300000-300100"
      )

      # limit(
      #   :query,
      #   :integer,
      #   "The numbers of items to return.",
      #   required: false,
      #   format: "int32",
      #   default: 10,
      #   minimum: 1,
      #   maximum: 1000,
      #   example: 1
      # )
    end

    response(200, "Returns multiple generations", Schema.ref(:BlocksResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :blocki_kbi do
    get("/blocki/{kbi}")
    description("Get key block information by given key block index(height).")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_kbi")
    tag("Middleware")

    parameters do
      kbi(:path, :integer, "The key block index(height)",
        required: true,
        example: 305_000
      )
    end

    response(
      200,
      "Returns key block information by given key block index(height)",
      Schema.ref(:BlockResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :blocki_kbi_and_mbi do
    get("/blocki/{kbi}/{mbi}")

    description(
      "Get micro block information by given key block index(height) and micro block index"
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_kbi_and_mbi")
    tag("Middleware")

    parameters do
      kbi(:path, :integer, "The key block index(height)",
        required: true,
        example: 300_001
      )

      mbi(:path, :integer, "The micro block index",
        required: true,
        example: 4
      )
    end

    response(
      200,
      "Returns micro block information by given key block index(height) and micro block index",
      Schema.ref(:BlockResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  def swagger_path_blocki(route = %{path: "/blocki/{kbi}"}), do: swagger_path_blocki_kbi(route)

  def swagger_path_blocki(route = %{path: "/blocki/{kbi}/{mbi}"}),
    do: swagger_path_blocki_kbi_and_mbi(route)
end
