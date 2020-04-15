defmodule AeMdwWeb.GenerationController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

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

  swagger_path :generations_by_range do
    get("/generations/{from}/{to}")
    description("Get generations between a given range")
    produces(["application/json"])
    deprecated(false)
    operation_id("generations_by_range")

    parameters do
      from(:path, :integer, "Start Generation or Key Block Number", required: true)
      to(:path, :integer, "End Generation or Key Block Number", required: true)
      limit(:query, :integer, "", required: false)
      page(:query, :integer, "", required: false)
    end

    response(200, "", %{})
  end

  def generations_by_range(conn, _params) do
    json(conn, @generations_by_range)
  end
end
