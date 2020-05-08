# AeMdw

## Overview

The middleware is a caching and reporting layer which sits in front of the nodes of the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

## Prerequisites
Ensure that you have [Elixir](https://elixir-lang.org/install.html).

## Setup the project
`git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`
  * This project depends on [æternity](https://github.com/aeternity/aeternity) node. It should be then compiled and the path to the node should be configured in `config.exs`, or you can simply export `NODEROOT`. If the variable is not set, by default the path is `../aeternity/_build/local/`.
```
export NODEROOT="path/to/your/node"
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
---
  * **All transactions between two heights(inclusive), optionally of type `tx_type`:**
```
GET /middleware/transactions/interval/<from>/<to><limit>&<page>&<txtype>
```

```
curl -s curl -s 'http://localhost:4000/middleware/transactions/interval/100/300?limit=1&page=1'

{
   "transactions":[
      {
         "block_hash":"mh_2SPER3HvFjCPcrqVta5AJHYfGswTSVfBvpb6zB68ApFFAfxmEc",
         "block_height":259,
         "hash":"th_UUhoMFAZnwxp55wsQ62Y59rsfxLBX8usHSahpY8kJDpaHnQMf",
         "micro_index":0,
         "micro_time":1543418748897,
         "signatures":[
            "sg_YHNHsFRQL8XSx32yCmmzp1hYoWhLh8Z1n7F7woapH8PTjR2bFnS6DfV2nCBbHsio5Du7fHxuxEsCkfnSa42faSasERpn8"
         ],
         "tx":{
            "amount":1000000,
            "fee":20000,
            "nonce":17,
            "payload":"ba_SGFucyBkb25hdGVzs/BHFA==",
            "recipient_id":"ak_oscBT9ZCXvcJ6DPW88avjbWLAv8HwsHufHfX9m83sfe6qYFnZ",
            "sender_id":"ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
            "type":"SpendTx",
            "version":1
         },
         "tx_index":23
      }
   ]
}
```
```
curl -s 'http://localhost:4000/middleware/transactions/interval/100/300?limit=1&page=1&txtype=NameClaimTx'

{
   "transactions":[
      {
         "block_hash":"mh_2MrzaVLDZM7txv7SUQYBUr6V6BRDDWuMELtUQMjtZZe3mNw2Tu",
         "block_height":194,
         "hash":"th_24BwirgsY9d979KZJ5wxaNfah2UCyzhvRYqe9RmNB9FWmoTgdz",
         "micro_index":0,
         "micro_time":1543407871282,
         "signatures":[
            "sg_LdDz6aAr1QWpamG6yxgn9xLco4DnXKxFzFeAbZkjGUQe9N971H7kn9EFF6tXErkbGBCyx2Q8zwMkSZLijMjCdWWuD6LYu"
         ],
         "tx":{
            "account_id":"ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
            "fee":20000,
            "name":"philipp.test",
            "name_salt":123,
            "nonce":2,
            "ttl":1000,
            "type":"NameClaimTx",
            "version":2
         },
         "tx_index":15
      }
   ]
}
```
---
  * **Returns the total of all transfers and the number of transactions for each date in a range:**
```
GET /middleware/transactions/rate/<from>/<to>
```
```
curl -s 'http://localhost:4000/middleware/transactions/rate/20190101/20190105'

```
---
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
TODO! It is not working for tx_type
```
curl -s 'http://localhost:4000/middleware/transactions/account/ak_2YBpaUCUKZWvHgmQXWQk5bBUzmVGKgbf1RQ3saFXneGJXkv3uH/to/ak_2tQGvA2fjUjcNzeAt4PiwHpGf27RtmYwvnCvuoDqQRAvKvZkcs?limit=1&page=1&txtype=NameClaimTx'


```
---
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
---
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
---
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
---
  * **Oracle’s transactions:**
```
GET /middleware/oracles/<oracle_id>?<limit>&<page>
```
```
curl -s 'http://localhost:4000/middleware/oracles/ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh?limit=1&page=1'


```
---
  * **A list of all state channels which have been opened, and not closed:**
```
GET /middleware/channels/active
```
```
curl -s 'http://localhost:4000/middleware/channels/active'


```
---
  * **For this state channel, show its on-chain transactions:**
```
GET /middleware/channels/transactions/address/<address>
```
```
curl -s 'http://localhost:4000/middleware/channels/transactions/address/ch_2tceSwiqxgBcPirX3VYgW3sXgQdJeHjrNWHhLWyfZL7pT4gZF4'


```
---
  * **All contracts, most recent first:**
```
GET /middleware/contracts/all?<limit>&<page>
```
```
curl -s 'http://localhost:4000/middleware/contracts/all?limit=2&page=1'

[
   {
      "block_height":250908,
      "contract_id":"ct_2uyRYUfzxP8nfvaWiw4AVFwHFtgNgdZEMcAvDAFd1Rd8ed18JC",
      "transaction_hash":"th_27V4UmRhyeSuPEDieXVuAdE3v42dDnLzPY6uism1bFhHCPfWKv"
   },
   {
      "block_height":250873,
      "contract_id":"ct_vSRAB45Z1kfCFSxDQCJjPiT4RAMWWwa1iehLEXyv2awVdwmKC",
      "transaction_hash":"th_w1zM6peugDu3mfSqMFksSCY2GbdJ2PjuAZ1dKYwJJqaJDGwb"
   }
]
```
---
  * **If the contract has calls, this endpoint returns them:**
```
GET /middleware/contracts/calls/address/<address>?<limit>&<page>
```
```
curl -s 'http://localhost:4000/middleware/contracts/calls/address/ct_AhMbfHYPBK8Qu1DkqXwQHcMKZoZAUndyYTNZDnyS1AdWh7X9U?limit=2&page=1'

[
   {
      "arguments":{
         "arguments":{
            "type":"tuple",
            "value":[
               {
                  "type":"list",
                  "value":[
                     {
                        "type":"tuple",
                        "value":[
                           {
                              "type":"word",
                              "value":14986354656192518382925446047860900756848227528093424515988224583964489617390
                           },
                           {
                              "type":"word",
                              "value":60000000000
                           }
                        ]
                     }
                  ]
               }
            ]
         },
         "function":"payout"
      },
      "caller_id":"ak_2vx4yNy2FUi7Fe2ZjKbKvpnabDTJE8RijtfAhQHNjY5zfj1We6",
      "callinfo":{
         "caller_id":"ak_2vx4yNy2FUi7Fe2ZjKbKvpnabDTJE8RijtfAhQHNjY5zfj1We6",
         "caller_nonce":2,
         "contract_id":"ct_AhMbfHYPBK8Qu1DkqXwQHcMKZoZAUndyYTNZDnyS1AdWh7X9U",
         "gas_price":1000000000,
         "gas_used":22150,
         "height":97941,
         "log":[

         ],
         "return_type":"ok",
         "return_value":"cb_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADfhHWADzMnYB"
      },
      "contract_id":"ct_AhMbfHYPBK8Qu1DkqXwQHcMKZoZAUndyYTNZDnyS1AdWh7X9U",
      "result":{
         "function":"payout",
         "result":{
            "type":"word",
            "value":60000000000
         }
      },
      "transaction_id":"th_NVCNN7txvnDJwT9S8Qb13ffX3E6GcfmfBLhXco8AwLLDZgpHm"
   }
]
```
---
  * **All transactions for this contract:**
```
GET /middleware/contracts/transactions/address/<address>?<limit>&<page>
```
```
curl -s 'http://localhost:4000/middleware/contracts/transactions/address/ct_AhMbfHYPBK8Qu1DkqXwQHcMKZoZAUndyYTNZDnyS1AdWh7X9U?limit=1&page=1'

{
   "transactions":[
      {
         "block_hash":"mh_bbAzJcovSNLNW1qwPMWkofdRsXShnQcHFzscyxLp7gxhoHuZB",
         "block_height":97934,
         "hash":"th_2raHdPQ8xtbE6oKh3z1pFmUpyFC5H7ZTBkNB8TuVydJjwedduL",
         "micro_index":0,
         "micro_time":1561019798515,
         "signatures":[
            "sg_Q3Ud2LKftTKKKCCWfEFLUs1THsczRS9xJjFvxowDBcvay3azYfyRumaF2aQnqSpHkWZ1GBBE2wbMUA7NBgnEinmLKFwyN"
         ],
         "tx":{
            "abi_version":1,
            "amount":0,
            "call_data":"cb_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACC5yVbyizFJqfWYeqUF89obIgnMVzkjQAYrtsG9n5+Z6gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnHQYrA==",
            "code":"cb_+QhpRgGgqQNVd4r2/yyoTbBfj5MFzMC1UeBDQro+Ve+ke+6Ev7P5Bs/5Ak2gqmFCUiigORZ09u2r5+47cRipSBbbt8qP5wUU5XnLwWiGcGF5b3V0uQHgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKD//////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcD//////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+QHLoLnJVvKLMUmp9Zh6pQXz2hsiCcxXOSNABiu2wb2fn5nqhGluaXS4YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//////////////////////////////////////////7kBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEA//////////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA///////////////////////////////////////////+QKuoPo8c94emJ3PC7jHvg6QmcI3EptLCBFzx9KYmzO4otqLh3BheW91dCe5AkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwP//////////////////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACIP//////////////////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC4QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC5AXFiAACPYgAAr5GAgIBRf7nJVvKLMUmp9Zh6pQXz2hsiCcxXOSNABiu2wb2fn5nqFGIAAUtXUICAUX+qYUJSKKA5FnT27avn7jtxGKlIFtu3yo/nBRTlecvBaBRiAADaV1CAUX/6PHPeHpidzwu4x74OkJnCNxKbSwgRc8fSmJszuKLaixRiAAFXV1BgARlRAFtgABlZYCABkIFSYCCQA2ADgVKQWWAAUVlSYABSYADzW2AAgFJgAPNbWVlgIAGQgVJgIJADYAAZWWAgAZCBUmAgkANgA4FSgVKQVltgIAFRUZBQWVCAkVBQgGAAkJFQW4GAYAEBYgABAFdQgJFQUJBWW4BgAQFiAAEQV1BgARlRAFuAUYBRkGAgAVGRYCABUWAAYABgAIRZYCABkIFSYCCQA2ABgVKGYABa8VCAg4UBlFCUUFBQUGIAAO5WW1BQgpFQUGIAALdWW2AgAVGAUZBgIAFRWVCBgZJQklBQYgAA7lYqt7+f",
            "deposit":0,
            "fee":1400000000000000,
            "gas":100000,
            "gas_price":1000000000,
            "nonce":1,
            "owner_id":"ak_2vx4yNy2FUi7Fe2ZjKbKvpnabDTJE8RijtfAhQHNjY5zfj1We6",
            "type":"ContractCreateTx",
            "version":1,
            "vm_version":4
         },
         "tx_index":2152877
      }
   ]
}
```
---
  * **The reward at a block height, which is comprised of the mining reward, and the fees for the transactions which are included:**
```
GET /middleware/reward/height/<height>
```
```
curl -s 'http://localhost:4000/middleware/reward/height/10000'


```
---
  * **The size of all transactions, in bytes, at the current height of the chain. This number is indicative.**
```
GET /middleware/size/current
```
```
curl -s 'http://localhost:4000/middleware/size/current'


```
---
  * **The same as above, but at some height:**
```
GET /middleware/size/height/<height>
```
```
curl -s 'http://localhost:4000/middleware/size/height/100'


```
---
  * **A status page, for monitoring purposes:**
```
GET /middleware/status
```
```
curl -s 'http://localhost:4000/middleware/status'


```
---
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

## Websocket interface
The websocket interface, which listens by default on port `4001`, gives asynchronous notifications when various events occur. 

### Message format:
```
{
"op": "<operation to perform>",
"payload": "<message payload>"
}
```

### Supported ops:
  * Subscribe
  * Unsubscribe

### Supported payload:
  * KeyBlocks
  * MicroBlocks
  * Transactions
  * Object, which takes a further field, `target` - can be any æternity type. So you may subscribe to any æternity object type, and be sent all transactions which reference the object. For instance if you have an oracle `ok_JcUaMCu9FzTwonCZkFE5BXsgxueagub9fVzywuQRDiCogTzse` you may subscribe to this object and be notified of any events which relate to it - presumable you would be interested in queries, to which you would respond. Of course you can also subscribe to accounts, contracts, names, whatever you like.


The websocket interface accepts JSON - encoded commands to subscribe and unsubscribe, and answers these with the list of subscriptions. A session will look like this:

```
wscat -c ws://localhost:4001/websocket
connected (press CTRL+C to quit)
> {"op":"Subscribe", "payload": "KeyBlocks"}
< ["KeyBlocks"]
> {"op":"Subscribe", "payload": "MicroBlocks"}
< ["KeyBlocks","MicroBlocks"]
> {"op":"Unsubscribe", "payload": "MicroBlocks"}
< ["KeyBlocks"]
> {"op":"Subscribe", "payload": "Transactions"}
< ["KeyBlocks","Transactions"]
> {"op":"Unsubscribe", "payload": "Transactions"}
< ["KeyBlocks"]
> {"op":"Subscribe", "payload": "Object", "target":"ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"}
< ["KeyBlocks","ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"]
< {"subscription":"KeyBlocks","payload":{"version":4,"time":1588935852368,"target":505727522,"state_hash":"bs_6PKt6GXM9Nu3As4XYr3kjmMiuJoTzkHUPDAwm21GBtjbpfWyL","prev_key_hash":"kh_2Dtcpq9ZdB7AJK1aeEwQtoSncDhFejSdzgTTwuNyscFzJrnsnJ","prev_hash":"mh_2H9cAZHHbyMzPwd4vjQHZpxXsrggG54VCryh6k1BTk511At8Bs","pow":[895666,52781556,66367943,73040389,83465124,91957344,137512183,139025150,145635838,147496688,174889700,196453040,223464154,236816295,249867489,251365348,253234990,284153380,309504789,316268731,337440038,348735058,352371122,367534696,378716232,396258628,400918205,407082251,424187867,427465210,430070369,430312387,432729464,438115994,440444207,442136189,473766117,478006149,482575574,489211700,498083855,518253098],"nonce":567855076671752,"miner":"ak_2Go59eRMNcdiq5uUvVAKjSRoxtREtJe6QvNdcAAPh9GiE5ekQi","info":"cb_AAACHMKhM24=","height":252274,"hash":"kh_FProa64FL423f3xok2fKTfbsuEP2QtdUM4idN7GidQ279zgZ1","beneficiary":"ak_2kHmiJN1RzQL6zXZVuoTuFaVLTCeH3BKyDMZKmixCV3QSWs3dd"}}
< {"subscription":"Object","payload":{"tx":{"version":1,"type":"SpendTx","ttl":252284,"sender_id":"ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs","recipient_id":"ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs","payload":"ba_MjUyMjc0OmtoX0ZQcm9hNjRGTDQyM2YzeG9rMmZLVGZic3VFUDJRdGRVTTRpZE43R2lkUTI3OXpnWjE6bWhfMmJTcFlDRVRzZ3hMZDd3eEx2Rkw5Wlp5V1ZqaEtNQXF6aGc3eVB6ZUNraThySFVTbzI6MTU4ODkzNTkwMjSozR4=","nonce":2044360,"fee":19320000000000,"amount":20000},"signatures":["sg_Kdh2uaoaiDEHoehDZsRHk7LvqUm5kPqyKR3RD71utjkkh5DTqoJeNWqYv4gRePL9FyBcU7oeL8nsT39zQg4ydCmiKUuhN"],"hash":"th_rGmoP9FCJMQMJKmwDE8gCk7i63vX33St3UiqGQsRGG1twHD7R","block_height":252274,"block_hash":"mh_2gYb8Pv1yLpdsPjxkzq8g9zzBVy42ZLDRvWH6aKYXhb8QjxdvU"}}
```
Actual chain data is wrapped in a JSON structure identifying the subscription to which it relates.