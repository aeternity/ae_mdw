# AeMdw

## Overview

The middleware is a caching and reporting layer which sits in front of the nodesof the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

## How to start
  * This project depends on [æternity](https://github.com/aeternity/aeternity) node. It should be then compiled and configured in `config.exs` file the path to the node or you can simply export `NODEROOT` to `aeternity/_build/local`:
```
export NODEROOT="your path to aeternity/_build/local"
```

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`
 
## HTTP interface

  * **All transactions for an account:**
```
GET /middleware/transactions/account/<account>?<limit>&<page>
```
```
$ curl -s 'http://localhost:4000/middleware/transactions/account/ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs?limit=1&page=1'

[
   {
      "block_hash":"mh_Gk5UMpjjeRz7uwp9h66uhwMZ4hWcHteb8xZDDFVJBf91witgg",
      "block_height":251931,
      "hash":"th_BJEmtkSNj7Z5AAvaP8RDXzdDfK6U4WjdgrJ4q4NaU5Apz6YNA",
      "micro_index":22,
      "micro_time":1588875498223,
      "signatures":[
         "sg_Ks3eGpMpkxvGqhjDaMrKjukNr4CJvnf39SxcQ4qJVR24rhuepXj4MKq1UimSb8E7mMQfadFi9SKeXoDs33ETN5VPudX9W"
      ],
      "tx":{
         "amount":20000,
         "fee":19320000000000,
         "nonce":2038361,
         "payload":"ba_MjUxOTMxOmtoX3BreUVUdlBNekpqb0tzY0RlNHY5SnFFTFBBV0RYZDNXNnNOOEZuOWM1TFJHVGdHNjk6bWhfMndTSFB0VGJNSDY0UVVFc3R4emJqckJERk05WGNER0t3c1pua0h0Y05jaHBzblE3eko6MTU4ODg3NTUwMd6FtiU=",
         "recipient_id":"ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
         "sender_id":"ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
         "ttl":251941,
         "type":"SpendTx",
         "version":1
      },
      "tx_index":10925501
   }
]
```
  * **All transactions between two heights(inclusive), optionally of type `tx_type`:**
```
GET /middleware/transactions/interval/<from>/<to><limit>&<page>&<txtype>
```

```
curl -s 'http://localhost:4000/middleware/transactions/interval/1/3?limit=1&page=1`

{
   "transactions":[
      {
         "block_hash":"mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
         "block_height":1,
         "hash":"th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
         "micro_index":0,
         "micro_time":1543375246712,
         "signatures":[
            "sg_Fipyxq5f3JS9CB3AQVCw1v9skqNBw1cdfe5W3h1t2MkviU19GQckERQZkqkaXWKowdTUvr7B1QbtWdHjJHQcZApwVDdP9"
         ],
         "tx":{
            "amount":150425,
            "fee":101014,
            "nonce":1,
            "payload":"ba_NzkwOTIxLTgwMTAxOGSbElc=",
            "recipient_id":"ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
            "sender_id":"ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
            "type":"SpendTx",
            "version":1
         },
         "tx_index":0
      }
   ]
}
```
  * **Returns the total of all transfers and the number of transactions for each date in a range:**
```
GET /middleware/transactions/rate/<from>/<to>
```
```
curl -s 'http://localhost:4000/middleware/transactions/rate/20190101/20190105'

```
  * **All SpendTX transactions from one account to another with optional type parameter limiting returned values (see above for tx_type example):**
```
GET /middleware/transactions/account/<sender>/to/<receiver>&<txtype>
```
```
curl -s 'http://localhost:4000/middleware/transactions/account/ak_2YBpaUCUKZWvHgmQXWQk5bBUzmVGKgbf1RQ3saFXneGJXkv3uH/to/ak_2tQGvA2fjUjcNzeAt4PiwHpGf27RtmYwvnCvuoDqQRAvKvZkcs?limit=1&page=1'

[
   {
      "block_hash":"mh_GkmbqmxCLieUyPnjKezr2nMr84ULHSyESWvoeXA5GgsZ9s3kp",
      "block_height":214033,
      "hash":"th_Yujp7Ey1kzMb8PyMnXhYnwbAaBPJ8wr3JgadS5zndzB2bdye3",
      "micro_index":33,
      "micro_time":1582011698254,
      "signatures":[
         "sg_Pfi8Lcv9Nx4wdx4XTsXALijmni7qyKXnGeG5yC3Y3Bi2W3Hs8qAyQuzbDBPmB6sXqd23ptBo4VQP5TvMUJLBwQu7U2ge6"
      ],
      "tx":{
         "amount":50000000000000000000,
         "fee":50000000000000,
         "nonce":2,
         "payload":"ba_Xfbg4g==",
         "recipient_id":"ak_2tQGvA2fjUjcNzeAt4PiwHpGf27RtmYwvnCvuoDqQRAvKvZkcs",
         "sender_id":"ak_2YBpaUCUKZWvHgmQXWQk5bBUzmVGKgbf1RQ3saFXneGJXkv3uH",
         "ttl":214133,
         "type":"SpendTx",
         "version":1
      },
      "tx_index":8026455
   }
]
```
  * **How many transactions does a particular account have:**
```
GET /middleware/transactions/account/<account>/count?<txtype>
```
```
curl -s 'http://localhost:4000/middleware/transactions/account/ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR/count

{
   "count":19301
}
```

  * **All generations between two heights:**
```
GET /middleware/generations/<from>/<to>
```
```
curl -s 'http://localhost:4000/middleware/generations/10/11'

{
   "data":{
      "10":{
         "beneficiary":"ak_2RGTeERHPm9zCo9EsaVAh8tDcsetFSVsD9VVi5Dk1n94wF3EKm",
         "hash":"kh_TKBhfcEynk9ttapsacvvuNnPJuq9wzkypVoupm1Mopc9poW2g",
         "height":10,
         "info":"cb_Xfbg4g==",
         "micro_blocks":{

         },
         "miner":"ak_2ox12gzKj7Av78YFVvDWNjygvBoA6DwKz7hcYeETGLDjahU5j3",
         "nonce":10003507761901478523,
         "pow":"[11191616, 26518153, 51581307, 70554579, 71991650, 83744389, 89211791, 91024019, 128834893, 134805543, 160888047, 165620756, 186131583, 186938090, 189016617, 200694827, 209146445, 226101150, 232717310, 254080300, 254271501, 262316567, 286404769, 312575703, 314932667, 320553930, 340842562, 342081223, 353862915, 354901154, 360935701, 378895664, 385928735, 428501613, 441643122, 464285959, 471446623, 489429813, 495455381, 513208695, 515136448, 527369566]",
         "prev_hash":"kh_2RGA3i6944pw8PM9TUTYanzbd4WgrYjLUamPjW789Vgqx9WWxH",
         "prev_key_hash":"kh_2RGA3i6944pw8PM9TUTYanzbd4WgrYjLUamPjW789Vgqx9WWxH",
         "state_hash":"bs_2pAUexcNWE9HFruXUugY28yfUifWDh449JK1dDgdeMix5uk8Q",
         "target":522133279,
         "time":1543376870213,
         "version":1
      },
      "11":{
         "beneficiary":"ak_2BMyg3B2p3KF4bosu7hyjvh2d38scnRyhU1H2peWdM2bMLBxqL",
         "hash":"kh_2CP6hGvh9SYCkKJXEZE8SBhvhBfPgyJfjW8tKxgdoGYWdzpaqE",
         "height":11,
         "info":"cb_Xfbg4g==",
         "micro_blocks":{

         },
         "miner":"ak_2frtLw4pPM4GQqf9DKry6xYvt3SyXXec4Lo6dAxGM5Q6KLx4xi",
         "nonce":5861939462010848357,
         "pow":"[15519545, 21172513, 29911846, 34789291, 91283456, 107890546, 139870994, 141894398, 147566753, 161714599, 174372444, 193372837, 215762846, 226903366, 241047163, 246122722, 249419984, 260167158, 262246476, 265812782, 277598780, 310962761, 319150867, 329971206, 348404540, 349005655, 361367666, 386467872, 387392797, 399661145, 406166464, 407032332, 407935085, 408271605, 408550883, 423879003, 473513896, 477098686, 479285003, 499658278, 513576771, 527132097]",
         "prev_hash":"kh_TKBhfcEynk9ttapsacvvuNnPJuq9wzkypVoupm1Mopc9poW2g",
         "prev_key_hash":"kh_TKBhfcEynk9ttapsacvvuNnPJuq9wzkypVoupm1Mopc9poW2g",
         "state_hash":"bs_2pAUexcNWE9HFruXUugY28yfUifWDh449JK1dDgdeMix5uk8Q",
         "target":522133279,
         "time":1543377442646,
         "version":1
      }
   }
}
```
  * **What was the height at a certain time, measured in milliseconds since Jan 1 1970 (i.e. UNIX time multiplied by 1,000):**
```
GET /middleware/height/at/<millis_since_epoch>
```
```
curl -s 'http://localhost:4000/middleware/height/at/1543375246777'

{
  "height": 2
}

```
  * **All oracles, most recently registered first:**
```
GET /middleware/oracles/list?<limit>&<page>
```
```
curl -s 'http://localhost:4000/middleware/oracles/list?limit=1&page=1'

[
   {
      "block_hash":"mh_Bgfjv5j2hwd8kzqv6Px3gjbEuWtK72sCYHtWXfyosKWqRhbeB",
      "block_height":251298,
      "expires_at":251798,
      "micro_index":92,
      "micro_time":1588758258208,
      "oracle_id":"ok_NcsdzkY5TWD3DY2f9o87MruJ6FSUYRiuRPpv5Rd2sqsvG1V2m",
      "signatures":[
         "sg_8VUnB3LaTfF3yGHP9rKhLwFF4ZT2TgdJe28EGcn4zAJCLQLmCNRc7aj3up6WNgTXtevXKqY9xnAHxx8HWEGbD2ZvTV6Y7"
      ],
      "transaction_hash":"th_2LFEqBAT3h514UbnH3JuMY3fymzMjnJr62fwu47HU21zso8sjf",
      "tx":{
         "abi_version":0,
         "account_id":"ak_NcsdzkY5TWD3DY2f9o87MruJ6FSUYRiuRPpv5Rd2sqsvG1V2m",
         "fee":16592000000000,
         "nonce":415,
         "oracle_ttl":{
            "type":"delta",
            "value":500
         },
         "query_fee":20000000000000,
         "query_format":"string",
         "response_format":"string",
         "type":"OracleRegisterTx",
         "version":1
      },
      "tx_index":10877319
   }
]
```