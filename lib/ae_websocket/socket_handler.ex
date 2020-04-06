defmodule AeWebsocket.SocketHandler do
  use Riverside, otp_app: :ae_mdw

  # Hardcoded data only for testing purpose
  @tx %{
    "payload" => %{
      "block_height" => 198_402,
      "block_hash" => "mh_WxZLeDdtnZce18ARdzwDXriEcSHWLH3SGZt8vznJFJ9jTe1NJ",
      "hash" => "th_2LRUdYLs5jpS7ESdDwCCxj7bcdcmuBb9rgoFPnVaHyKHfB5sx3",
      "signatures" => [
        "sg_3FJfvWsZfVjicYQCxJJkS83B4RFq5avvqvpMsqNLU2wANrwP3bNjtwQhyE6CbMWMb38WZab4pEJLLaERfbGcyT91UmRGZ"
      ],
      "tx" => %{
        "amount" => 20000,
        "fee" => 19_320_000_000_000,
        "nonce" => 1_087_210,
        "payload" =>
          "ba_MTk4NDAxOmtoXzJzY0FoOHE5QmV5d2FGYTRUbnZSdVZkRktWMUVUWlo3YURIdHJvZ3N6THJWd05yMm16Om1oX3VWZHdtVU40aUVnNkx6ZEI2emQyekhuMjhCRXBuSzd3Znk3NktWTXFwZFhrTWZRZ1k6MTU3OTE4MjYyMUJarn4=",
        "recipient_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
        "sender_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
        "type" => "SpendTx",
        "version" => 1
      }
    },
    "subscription" => "Transactions"
  }

  @mb %{
    "payload" => %{
      "hash" => "mh_WxZLeDdtnZce18ARdzwDXriEcSHWLH3SGZt8vznJFJ9jTe1NJ",
      "key_block_id" => 198_402,
      "pof_hash" => "no_fraud",
      "prev_hash" => "kh_2ijsPVenQBS7U1QReweRX2mHEQDRNZEUqZsnVYyJ4ReXQDikTS",
      "prev_key_hash" => "kh_2ijsPVenQBS7U1QReweRX2mHEQDRNZEUqZsnVYyJ4ReXQDikTS",
      "signature" =>
        "sg_3SomHhaS2xVSMNZomNQeC7BbM3KVjpwnNw3bTMasaM233h7NAgoEDbacHMobRM5QLqcczDLcYLWqiMx1tWw1GmRE9bHtC",
      "state_hash" => "bs_ebCiqWgV99CLEVrjTJTjYBuZqmrFpXueLJ6ZbHeETbF8Sv27",
      "time" => 1_579_182_623_719,
      "txs_hash" => "bx_NZjsRwyvQc2aJhcxboSaDM9J5JKssEHxiHwYEnLcVGmiUEuUk",
      "version" => 4
    },
    "subscription" => "MicroBlocks"
  }

  @kb %{
    "payload" => %{
      "beneficiary" => "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash" => "kh_2ijsPVenQBS7U1QReweRX2mHEQDRNZEUqZsnVYyJ4ReXQDikTS",
      "height" => 198_402,
      "info" => "cb_AAAAAj0XPPM=",
      "miner" => "ak_Sad8WiQ7D2KREUmVAbstUdZiPpeV7tKP9vbpKf4FD3iPtoUWk",
      "nonce" => 7_570_280_923_249_522_519,
      "pow" => [
        12_370_566,
        29_071_319,
        38_204_973,
        75_014_689,
        91_287_558,
        114_045_135,
        126_101_497,
        153_152_507,
        158_506_844,
        170_851_730,
        184_564_481,
        199_212_540,
        213_906_768,
        227_042_011,
        235_259_316,
        235_722_811,
        239_781_459,
        244_688_574,
        270_481_127,
        296_476_557,
        314_601_111,
        315_798_875,
        338_002_652,
        338_092_021,
        347_836_373,
        356_959_654,
        357_142_603,
        363_648_593,
        375_811_960,
        379_104_189,
        396_439_095,
        407_233_623,
        428_902_072,
        429_360_562,
        451_378_998,
        472_454_754,
        495_023_943,
        500_834_680,
        500_942_395,
        521_168_150,
        523_375_819,
        534_602_995
      ],
      "prev_hash" => "mh_ai1UfvSTekdUVPuDgM1AV8sPn8QfSHthYUBZgmPkvo4PuVGB4",
      "prev_key_hash" => "kh_2scAh8q9BeywaFa4TnvRuVdFKV1ETZZ7aDHtrogszLrVwNr2mz",
      "state_hash" => "bs_MFJWPux8fngat9tZzVEA5CEGgLd7g94zNqoMGyyijwwsQ9zwR",
      "target" => 504_570_182,
      "time" => 1_579_182_612_543,
      "version" => 4
    },
    "subscription" => "KeyBlocks"
  }

  @obj %{
    payload: %{
      block_hash: "mh_NQbxCQHSHx16DPcoAVCj6FXoqixBvgkSxcDF1JM8icdymRdw9",
      block_height: 236_627,
      hash: "th_2m9NS58bCPKeq71y557AqAgAyT1PapaYHyFduyisEjsuMntsv7",
      signatures: [
        "sg_CsLgb8H3ta6cgujQUkydunvbAo1GZgmUpGJybS51hcN5CHWg2MNV25mkQYNE65Zfs1nmrfZpq71LZPMYtzqocLsYw9oHe"
      ],
      tx: %{
        amount: 10,
        fee: 16_680_000_000_000,
        nonce: 198,
        payload: "ba_Xfbg4g==",
        recipient_id: "ak_2q5ESPrAyyxXyovUaRYE6C9is93ZCXmfTfJxGH9oWkDV6SEa1R",
        sender_id: "ak_2q5ESPrAyyxXyovUaRYE6C9is93ZCXmfTfJxGH9oWkDV6SEa1R",
        type: "SpendTx",
        version: 1
      }
    },
    subscription: "Object"
  }

  @impl Riverside
  def init(session, state) do
    {:ok, session, state}
  end

  @impl Riverside
  def handle_message(
        %{"op" => "Subscribe", "payload" => "Object", target: account},
        session,
        state
      ) do
    deliver_me(@obj)
    {:ok, session, state}
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, state) do
    Riverside.LocalDelivery.join_channel(payload)
    deliver_me([payload])
    {:ok, session, state}
  end

  def handle_message(%{"op" => "Unsubscribe", "payload" => payload}, session, state) do
    Riverside.LocalDelivery.leave_channel(payload)
    {:ok, session, state}
  end
end
