defmodule AeMdwWeb.GenerationController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Util, as: WebUtil
  require Model

  import AeMdw.{Sigil, Db.Util, Util}

  # Hardcoded DB only for testing purpose
  @generations_by_range %{
    "data" => %{
      "1" => %{
        "beneficiary" => "ak_2RGTeERHPm9zCo9EsaVAh8tDcsetFSVsD9VVi5Dk1n94wF3EKm",
        "hash" => "kh_29Gmo8RMdCD5aJ1UUrKd6Kx2c3tvHQu82HKsnVhbprmQnFy5bn",
        "height" => 1,
        "micro_blocks" => %{
          "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP" => %{
            "hash" => "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
            "pof_hash" => "no_fraud",
            "prev_hash" => "kh_29Gmo8RMdCD5aJ1UUrKd6Kx2c3tvHQu82HKsnVhbprmQnFy5bn",
            "prev_key_hash" => "kh_29Gmo8RMdCD5aJ1UUrKd6Kx2c3tvHQu82HKsnVhbprmQnFy5bn",
            "signature" =>
              "sg_91zukFywhEMuiFCVwgJWEX6mMUgHiB3qLux8QYDHXnbXAcgWxRy7S5JcnbMjdfWNSwFjpXnJVp2Fm5zzvLVzcCqDLT2zC",
            "state_hash" => "bs_2pAUexcNWE9HFruXUugY28yfUifWDh449JK1dDgdeMix5uk8Q",
            "time" => 1_543_375_246_712,
            "transactions" => %{
              "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR" => %{
                "block_hash" => "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
                "block_height" => 1,
                "hash" => "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
                "signatures" => [
                  "sg_Fipyxq5f3JS9CB3AQVCw1v9skqNBw1cdfe5W3h1t2MkviU19GQckERQZkqkaXWKowdTUvr7B1QbtWdHjJHQcZApwVDdP9"
                ],
                "tx" => %{
                  "amount" => 150_425,
                  "fee" => 101_014,
                  "nonce" => 1,
                  "payload" => "ba_NzkwOTIxLTgwMTAxOGSbElc=",
                  "recipient_id" => "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
                  "sender_id" => "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
                  "type" => "SpendTx",
                  "version" => 1
                }
              }
            },
            "txs_hash" => "bx_8K5NtXK56QmUAsriAYocpqAUowJMsbEJmHEGrz7SRiu1g1yjo",
            "version" => 1
          }
        },
        "miner" => "ak_q9KDcpGHQ377rVS1TU2VSofby2tXWPjGvKizfGUC86gaq7rie",
        "nonce" => "7537663592980547537",
        "pow" =>
          "[26922260, 37852188, 59020115, 60279463, 79991400, 85247410, 107259316, 109139865, 110742806, 135064096, 135147996, 168331414, 172261759, 199593922, 202230201, 203701465, 210434810, 231398482, 262809482, 271994744, 272584245, 287928914, 292169553, 362488698, 364101896, 364186805, 373099116, 398793711, 400070528, 409055423, 410928197, 423334086, 423561843, 428130074, 496454011, 501715005, 505858333, 514079183, 522053501, 526239399, 527666844, 532070334]",
        "prev_hash" => "kh_pbtwgLrNu23k9PA6XCZnUbtsvEFeQGgavY4FS2do3QP8kcp2z",
        "prev_key_hash" => "kh_pbtwgLrNu23k9PA6XCZnUbtsvEFeQGgavY4FS2do3QP8kcp2z",
        "state_hash" => "bs_QDcwEF8e2DeetViw6ET65Nj1HfPrQh1uRkxtAsaGLntRGXpg7",
        "target" => 522_133_279,
        "time" => 1_543_373_685_748,
        "version" => 1
      },
      "2" => %{
        "beneficiary" => "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS",
        "hash" => "kh_Z6iGf4ajdT5nhRMRtE7iLCii1BLQS4govtSiFwnfRtHZRxubz",
        "height" => 2,
        "micro_blocks" => %{},
        "miner" => "ak_2GRQehEg2PgyFKBhtfuGEBA5JR4JmQyKo2mxdT7kBcrKYKhE1i",
        "nonce" => "5900433900970191660",
        "pow" =>
          "[5101167, 6731386, 32794521, 37862469, 82304394, 88947395, 96272418, 117165693, 128680663, 130957359, 138202691, 145997910, 148853998, 158275375, 161243335, 190430513, 198310271, 213658699, 216705056, 223898939, 235521909, 242195781, 244411339, 259255091, 274739784, 274765835, 298847001, 303666419, 308332831, 344614579, 352648945, 359486160, 364216435, 365891779, 371759238, 377325461, 379358071, 419687839, 439118573, 440188602, 479121064, 513335347]",
        "prev_hash" => "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
        "prev_key_hash" => "kh_29Gmo8RMdCD5aJ1UUrKd6Kx2c3tvHQu82HKsnVhbprmQnFy5bn",
        "state_hash" => "bs_2pAUexcNWE9HFruXUugY28yfUifWDh449JK1dDgdeMix5uk8Q",
        "target" => 522_133_279,
        "time" => 1_543_375_246_777,
        "version" => 1
      }
    },
    "total_micro_blocks" => 1,
    "total_transactions" => 1
  }

  # Each generation can have many micro blocks, each micro blocks can have many transactions...
  # Now, we do this for several (11) generations - may result in thousands of DB reads
  # and serializing thousands of TXs...
  # There's massive amount of work to do at once - the result should be cached!! (TODO)
  # (why isn't frontend asking generation's inner data (microblocks/txs) lazily ?!?!)

  # this request is spammig server - frontend bug
  def interval(conn, %{"from" => "undefined", "to" => "undefined"}) do
    conn
    |> send_resp(400, "{\"reason\":\"frontend bug\"}")
    |> halt
  end

  def interval(conn, req) do
    last_gen = last_gen()
    put_gen = fn gen, acc -> put_in(acc, ["#{gen["height"]}"], gen) end
    generations = Stream.map(scope(req, last_gen), &generation(&1, last_gen))
    json(conn, %{"data" => Enum.reduce(generations, %{}, put_gen)})
  end

  ##########

  def generation(height, last_gen),
    do: generation(block_jsons(height, last_gen))

  def generation([kb_json | mb_jsons]) do
    kb_json =
      (Map.has_key?(kb_json, "pow") &&
         update_in(kb_json["pow"], &"#{inspect(&1)}")) ||
        kb_json

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
  end

  def block_jsons(height, last_gen) when height < last_gen,
    do: height |> DBS.map(~t[block], :json) |> Enum.to_list()

  def block_jsons(last_gen, last_gen) do
    {:ok, %{key_block: kb, micro_blocks: mbs}} = :aec_chain.get_current_generation()
    ^last_gen = :aec_blocks.height(kb)

    for block <- [kb | mbs] do
      header = :aec_blocks.to_header(block)
      :aec_headers.serialize_for_client(header, prev_block_type(header))
    end
  end

  defp scope(req, last_gen) do
    %Range{first: f, last: l} = WebUtil.scope(req)
    Range.new(min(f, last_gen), l)
  end
end
