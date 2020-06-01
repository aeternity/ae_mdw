# AeMdw

## Overview

The middleware is a caching and reporting layer which sits in front of the nodes of the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

## Prerequisites
Ensure that you have [Elixir](https://elixir-lang.org/install.html) installed.

## Setup the project
`git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`
  * This project depends on [æternity](https://github.com/aeternity/aeternity) node. It should be then compiled and the path to the node should be configured in `config.exs`, or you can simply export `NODEROOT`. If the variable is not set, by default the path is `../aeternity/_build/local/`.
```
export NODEROOT="path/to/your/node"
```

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `make shell`

## HTTP interface

HTTP endpoints which return a subset of all possible results allow specifying a scope the client is interested in.

### Scope

Scope determines the range of results to iterate over, as well as direction:

- forward   - from beginning to the end
- backward  - from end to the beginning
- gen/A-B   - from generation A to B (forward if A < B, backward otherwise)
- txi/A-B   - from transaction index A to B (forward if A < B, backward otherwise)

### Query

There are two types of queries, which can't be mixed:

- property based - allowing to specify ID (account) of interest, along with type of transaction (or type_group - grouping channel, contract, ga, name or other types together)

- field based - allowing to query transactions having a specific ID in a particular field(s) of transaction record. The fields must be prefixed with TX type (without `_tx` suffix), e.g.: spend.sender_id. (performance of these queries may need to be addressed later, but API shouldn't change)


There are also two types of combinators which specify how to interpret if transaction in question matches the query:

- OR - at least one query (type) parameter matches (except IDs, provided by account parameter)
- AND - all query parameters must match

(TODO: better explanation of ID/type query combinations)

### Pagination

All endpoints which allow specifying of scope return a link in the reply, which can be used to get the following page in the result set.


** TRANSACTION endpoints **

* TX - get transaction by hash

```
curl -s "http://35.159.10.159:4000/tx/th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq"

{
  "block_hash": "mh_2kE3N7GCaeAiowu1a7dopJygxQfxvRXYCNy7Pc657arjCa8PPe",
  "block_height": 257058,
  "hash": "th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq",
  "micro_index": 19,
  "micro_time": 1589801584978,
  "signatures": [
    "sg_Z7bbM2a8tDZchtpAkQuMrw5S3cf3yvVizx5qb6hB58KJBBTqhCcpgq2adwNz9SneSQgzD6QQSToiKn3XosS7qybacLpiG"
  ],
  "tx": {
    "amount": 20000,
    "fee": 19300000000000,
    "nonce": 2129052,
    "payload": "ba_MjU3MDU4OmtoXzhVdnp6am9tZG9ZakdMNURic2hhN1RuMnYzYzNXWWNCVlg4cWFQV0JyZjcyVHhSeWQ6bWhfald1dnhrWTZReXBzb25RZVpwM1B2cHNLaG9ZMkp4cHIzOHhhaWR2aWozeVRGaTF4UDoxNTg5ODAxNTkxQa+0cQ==",
    "recipient_id": "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
    "sender_id": "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
    "ttl": 257068,
    "type": "SpendTx",
    "version": 1
  },
  "tx_index": 11306257
}
```

* TXI - get transaction by index

```
curl -s "http://35.159.10.159:4000/txi/10000000"

{
  "block_hash": "mh_2J4A4f7RJ4oVKKCFmBEDMQpqacLZFtJ5oBvx3fUUABmLv5SUZH",
  "block_height": 240064,
  "hash": "th_qYi26SEQoW9baWkwfenWxLCveQ1QNSThEzxxWzfHTscfcfovs",
  "micro_index": 94,
  "micro_time": 1586725056043,
  "signatures": [
    "sg_WomDtVzmhoJ2fitFkHGMEciwgmQ4FqXW1mZ5W9GNFenpsTSSduPA8iswWZnU4xma2g9EzJy8a5EPqtSf1dMZNY1pT7A55"
  ],
  "tx": {
    "amount": 20000,
    "fee": 19340000000000,
    "nonce": 1826406,
    "payload": "ba_MjQwMDY0OmtoXzJ2aFpmRUJSZGpEY2V6Mm5aa3hTU1FHS2tRb0FtQUhrbWhlVU03ZEpFekdBd0pVaVZvOm1oXzJkWEQzVHNqMmU2MUttdFVLRFNLdURrdEVOWXdWZDJjdUhMYUJZTUhKTUZ1RnYydmZpOjE1ODY3MjUwNTYoz+LD",
    "recipient_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
    "sender_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
    "ttl": 240074,
    "type": "SpendTx",
    "version": 1
  },
  "tx_index": 10000000
}
```

* TXS - get transactions or their count

### TXS/COUNT endpoint

Requests where scope is provided should be used carefully.
It's easy to trigger counting of millions of transactions, which takes significant amount of time. Therefore, the querying power of this endpoint may be limited in the future, depending on the usage patterns.

* All transactions:

```
curl -s "http://35.159.10.159:4000/txs/count"

{
  "count": 11339717
}
```

* In generations range:

```
curl -s "http://35.159.10.159:4000/txs/gen/819-1000/count"

{
  "count": 11
}
```

* In generation range 50000-51000, counting any channel OR contract transaction:

```
curl -s "http://35.159.10.159:4000/txs/gen/50000-51000/count/or?type_group=channel&type_group=contract"

{
  "count": 12
}
```

* In generation range 50000-51000, counting spend transactions where sender_id = ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv AND recipient_id = ak_2FurtphSnS4S512ZioQgXg4yEXTuXPEEMVAUuzdReioYqY6mxa:

```
curl -s "http://35.159.10.159:4000/txs/gen/50000-51000/count/and?spend.sender_id=ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv&spend.recipient_id=ak_2FurtphSnS4S512ZioQgXg4yEXTuXPEEMVAUuzdReioYqY6mxa"

{
  "count": 2
}

```

### TXS endpoint

The `limit` parameter in the query specifies how many results should be in the reply.
In the following examples, the `limit` parameter is set to 1, for demonstration.
Usually, it should not be provided and in that case the `limit` defaults to 10.

* All transactions, latest first:

```
curl -s "http://35.159.10.159:4000/txs/backward?limit=1"

{
  "data": [
    {
      "block_hash": "mh_8baqCgUAPP63M8T9nJnFBU67fLWLbZcjC5nEPsvk8YpXUwjQv",
      "block_height": 257526,
      "hash": "th_K7xJW17nMhr86h7hHZseLx4GubDgLTbLuw5q2VcfM2qQZUC16",
      "micro_index": 85,
      "micro_time": 1589888424100,
      "signatures": [
        "sg_FVGXi2ar4nJUHrJJVheb9iWLZh32pSZhVTwfDBYiji7pyJxaNhZXwPmyHLgSsqzAgqA8g34pDKUtxJnqYS13kAwgWVFwL"
      ],
      "tx": {
        "amount": 20000,
        "fee": 19320000000000,
        "nonce": 2139604,
        "payload": "ba_MjU3NTI2OmtoX3dVM1BodnNIYlNnd1dweHFqb1A4RXdmbzRFZlFveWNURjFWNGtYODg3VVFUdTc4UVA6bWhfMmg5OVNOTXNFYXVCZURjQ3JYblB3U01jWjZUYzM4UTlLekZGbjYzcWNzRk04TkpnYVc6MTU4OTg4ODQyNds7xCg=",
        "recipient_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
        "sender_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
        "ttl": 257536,
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 11341937
    }
  ],
  "next": "txs/gen/257527-0?limit=1&page=2"
}
```

* All transactions, earliest first:

```
curl -s "http://35.159.10.159:4000/txs/forward?limit=1"

{
  "data": [
    {
      "block_hash": "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
      "block_height": 1,
      "hash": "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
      "micro_index": 0,
      "micro_time": 1543375246712,
      "signatures": [
        "sg_Fipyxq5f3JS9CB3AQVCw1v9skqNBw1cdfe5W3h1t2MkviU19GQckERQZkqkaXWKowdTUvr7B1QbtWdHjJHQcZApwVDdP9"
      ],
      "tx": {
        "amount": 150425,
        "fee": 101014,
        "nonce": 1,
        "payload": "ba_NzkwOTIxLTgwMTAxOGSbElc=",
        "recipient_id": "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
        "sender_id": "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 0
    }
  ],
  "next": "txs/gen/0-257533?limit=1&page=2"
}
```

* All transactions in range specified by generations:

```
curl -s "http://35.159.10.159:4000/txs/gen/100000-100010?limit=1"

{
  "data": [
    {
      "block_hash": "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS",
      "block_height": 100000,
      "hash": "th_VAGQK8LmPQ5NvQ6kJZz7rhQdMJ5nTJZ9uHRbDKRWDGD4Ex5Gj",
      "micro_index": 0,
      "micro_time": 1561390173025,
      "signatures": [
        "sg_RXp8FEo8cDwiy61S9fkH6dJrMjZL2Cri5FJLbK8Q7VWXamX5eh2CBvL1cjsy6BW8hizvruXdDt5vUhJH1NA4Ye9qUEX8i"
      ],
      "tx": {
        "amount": 5e+21,
        "fee": 20000000000000,
        "nonce": 720,
        "payload": "ba_Xfbg4g==",
        "recipient_id": "ak_2B6nPK6HLK5Yp7qMbMeLMSDJwxNdypbDzW3xm938uw2a7EemdQ",
        "sender_id": "ak_2mggc8gkx9nhkciBtYbq39T6Jzd7WBms6jgYoLAAeRNgdy3Md6",
        "ttl": 100500,
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 2160628
    }
  ],
  "next": "txs/gen/100000-100010?limit=1&page=2"
}
```

* All transactions in range specified by transaction indices:

```
curl -s "http://35.159.10.159:4000/txs/txi/1000000-1000010?limit=1"

{
  "data": [
    {
      "block_hash": "mh_zfnKKWbUt84ZkzGbkNZEQYgsXhcLgypUK4eeMk2ZWARpSpy9b",
      "block_height": 44495,
      "hash": "th_84uc6avLpH8WFMbvnYkPWSeiiCpm9wXZUnPMm5JSrjJH4djAB",
      "micro_index": 43,
      "micro_time": 1551367578947,
      "signatures": [
        "sg_3GcpsLwp53hdcJmXPqyAJoP9hV4xdQBnmCyMCZJoFXzQ5tLvva8tSjU2MoLUEenxUnxjq3JNXPo8CgiJVsSTf9M8LhgUe"
      ],
      "tx": {
        "account_id": "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx",
        "commitment_id": "cm_NveuxcfftEabuggX1zjyc1n7NhccwvRfKNCXmWFPzhemPqwrx",
        "fee": 21000000000000,
        "nonce": 56,
        "ttl": 44595,
        "type": "NamePreclaimTx",
        "version": 1
      },
      "tx_index": 1000000
    }
  ],
  "next": "txs/txi/1000000-1000010?limit=1&page=2"
}
```

* All name related transactions for particular account, from latest:

```
curl -s "http://35.159.10.159:4000/txs/backward/or?limit=1&account=ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx&type_group=name"

{
  "data": [
    {
      "block_hash": "mh_2tL4tRRnH6WLzzYca7T7vQUbdUCRZEeq58S5giwAtnbkjjb3Vj",
      "block_height": 85694,
      "hash": "th_2pvhiLSonrEsmJiUf9Q3E3Lkt9ki5MpHGJ9qQsCVt8ACNWpVVc",
      "micro_index": 30,
      "micro_time": 1558804725247,
      "signatures": [
        "sg_P7UFr4iySfJpidyitDqVTF86uhnuYjQVJ46c96jC4nYZys5mBDQVbsV4CLxYpCqKU55SySmkcSg3Xg4dcYk4aFJGm3VjF"
      ],
      "tx": {
        "account_id": "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx",
        "client_ttl": 84600,
        "fee": 30000000000000,
        "name_id": "nm_t13Kcjan1mRu2sFjdMgeeASSSL8QoxmVhTrFCmji1j1DZ4jhb",
        "name_ttl": 50000,
        "nonce": 151,
        "pointers": [
          {
            "id": "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx",
            "key": "account_pubkey"
          }
        ],
        "type": "NameUpdateTx",
        "version": 1
      },
      "tx_index": 2107840
    }
  ],
  "next": "txs/backward/or?account=ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx&limit=1&page=2&type_group=name"
}
```

* All channel related transactions for particular accounts in generations range:

```
curl -s "http://35.159.10.159:4000/txs/gen/0-100000/or?limit=1&account=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&account=ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq&type_group=channel"

{
  "data": [
    {
      "block_hash": "mh_2aw4KGSWLq7opXT796a5QZx8Hd7BDaGRSwEcyqzNQMii7MrGrv",
      "block_height": 1208,
      "hash": "th_25ofE3Ah8Fm3PV8oo5Trh5rMMiU4E8uqFfncu9EjJHvubumkij",
      "micro_index": 0,
      "micro_time": 1543584946527,
      "signatures": [
        "sg_2NjzKD4ZKNQiqjAYLVFfVL4ZMCXUhVUEXCmoAZkhAZxsJQmPfzWj3Dq6QnRiXmJDByCPc33qYdwTAaiXDHwpdjFuuxwCT",
        "sg_Wpm8j6ZhRzo6SLnaqWUb24KwFZ7YLws9zHiUKvWrf89cV2RAYGqftXBAzS6Pj7AVWKQLwSjL384yzG7hK4rHB8dn2d67g"
      ],
      "tx": {
        "channel_reserve": 10,
        "delegate_ids": [],
        "fee": 20000,
        "initiator_amount": 50000,
        "initiator_id": "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS",
        "lock_period": 3,
        "nonce": 1,
        "responder_amount": 50000,
        "responder_id": "ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq",
        "state_hash": "st_MHb9b2dXovoWyhDf12kVJPwXNLCWuSzpwPBvMFbNizRJttaZ",
        "type": "ChannelCreateTx",
        "version": 1
      },
      "tx_index": 87
    }
  ],
  "next": "txs/gen/0-100000/or?account=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&account=ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq&limit=1&page=2&type_group=channel"
}
```

* Spend transactions in range between sender and recipient:

```
curl -s "http://35.159.10.159:4000/txs/gen/50000-51000/and?limit=1&spend.sender_id=ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv&spend.recipient_id=ak_2FurtphSnS4S512ZioQgXg4yEXTuXPEEMVAUuzdReioYqY6mxa"

{
  "data": [
    {
      "block_hash": "mh_a5ptAsuxsCc9kHUEvWYf5WDxGzCAX4poGGXVvPpJhY8BDw8Nw",
      "block_height": 50010,
      "hash": "th_2mTC1xyFWcSptXiNpGpQ868eB8N9wwLMGogg8WZBZ5JodqZHip",
      "micro_index": 34,
      "micro_time": 1552364962104,
      "signatures": [
        "sg_XhKx8qtfduR5uqnkLyvPuuES5nsAaRiey8Ag7hbzczxwBj64RxzNGZYha4z5QqfaJw4QwGyt3moMyqLTwZqawuCQTxhtY"
      ],
      "tx": {
        "amount": 37595500000000000000,
        "fee": 20500000000000,
        "nonce": 127174,
        "payload": "ba_VGltZSBpcyBtb25leSwgbXkgZnJpZW5kcy4gL1lvdXJzIEJlZXBvb2wuLyrtvsY=",
        "recipient_id": "ak_2FurtphSnS4S512ZioQgXg4yEXTuXPEEMVAUuzdReioYqY6mxa",
        "sender_id": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 1516960
    }
  ],
  "next": "txs/gen/50000-51000/and?limit=1&page=2&spend.recipient_id=ak_2FurtphSnS4S512ZioQgXg4yEXTuXPEEMVAUuzdReioYqY6mxa&spend.sender_id=ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv"
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

### Supported operations:
  * Subscribe
  * Unsubscribe

### Supported payloads:
  * KeyBlocks
  * MicroBlocks
  * Transactions
  * Object, which takes a further field, `target` - can be any æternity entity. So you may subscribe to any æternity object type, and be sent all transactions which reference the object. For instance, if you have an oracle `ok_JcUaMCu9FzTwonCZkFE5BXsgxueagub9fVzywuQRDiCogTzse` you may subscribe to this object and be notified of any events which relate to it - presumable you would be interested in queries, to which you would respond. Of course you can also subscribe to accounts, contracts, names, whatever you like.


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
