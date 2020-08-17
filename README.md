# AeMdw - Aeternity Middleware

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [AeMdw - Aeternity Middleware](#aemdw---aeternity-middleware)
    - [Overview](#overview)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Start](#start)
    - [HTTP endpoints](#http-endpoints)
    - [Transaction querying](#transaction-querying)
        - [Scope](#scope)
        - [Query parameters](#query-parameters)
            - [Types](#types)
                - [Supported types](#supported-types)
                - [Supported type groups](#supported-type-groups)
                    - [Examples](#examples)
            - [Generic IDs](#generic-ids)
                - [Supported generic IDs](#supported-generic-ids)
                    - [Examples](#examples-1)
            - [Transaction fields](#transaction-fields)
                - [Supported fields with provided transaction type](#supported-fields-with-provided-transaction-type)
                - [Supported freestanding fields](#supported-freestanding-fields)
                    - [Examples](#examples-2)
            - [Pagination](#pagination)
                - [Examples](#examples-3)
        - [Mixing of query parameters](#mixing-of-query-parameters)
            - [Examples](#examples-4)
    - [Querying from Elixir's shell](#querying-from-elixirs-shell)
        - [MAP function](#map-function)
        - [Arguments](#arguments)
            - [Scope](#scope-1)
            - [Mapper](#mapper)
            - [Query](#query)
            - [Prefer Order](#prefer-order)
        - [Examples](#examples-5)
            - [Continuation example](#continuation-example)
    - [Other transaction related endpoints](#other-transaction-related-endpoints)
        - [TX - get transaction by hash](#tx---get-transaction-by-hash)
        - [TXI - get transaction by index](#txi---get-transaction-by-index)
        - [TXS/COUNT endpoint](#txscount-endpoint)
            - [All transactions](#all-transactions)
            - [Transactions by type/field for ID](#transactions-by-typefield-for-id)
    - [Naming System](#naming-system)
        - [Name Resolution](#name-resolution)
        - [Listing names](#listing-names)
            - [All names](#all-names)
            - [Inactive names](#inactive-names)
            - [Active names](#active-names)
            - [Auctions](#auctions)
        - [Pointers](#pointers)
        - [Pointees](#pointees)
    - [Websocket interface](#websocket-interface)
        - [Message format:](#message-format)
        - [Supported operations:](#supported-operations)
        - [Supported payloads:](#supported-payloads)
    - [Tests](#tests)
        - [Controller tests](#controller-tests)
        - [Performance test](#performance-test)

<!-- markdown-toc end -->


## Overview

The middleware is a caching and reporting layer which sits in front of the nodes of the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

## Prerequisites

Ensure that you have [Elixir](https://elixir-lang.org/install.html) installed, using Erlang 22 or newer.

## Setup

`git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`
  * This project depends on [æternity](https://github.com/aeternity/aeternity) node. It should be then compiled and the path to the node should be configured in `config.exs`, or you can simply export `NODEROOT`. If the variable is not set, by default the path is `../aeternity/_build/local/`.

```
export NODEROOT="path/to/your/node"
```
The NODEROOT directory should contain directories: `bin`, `lib`, `plugins`, `rel` of AE node installation.

## Start

  * Install dependencies with `mix deps.get`
  * Start middleware with `make shell`

## HTTP endpoints

```
GET  /tx/:hash                - returns transaction by hash
GET  /txi/:index              - returns transaction by index (0 .. last transaction index)
GET  /txs/count               - returns total number of transactions (last transaction index + 1)
GET  /txs/count/:id           - returns counts of transactions per transaction field for given id
GET  /txs/:scope_type/:range  - returns transactions bounded by scope/range where query is in query string
GET  /txs/:direction          - returns transactions from beginning (forward) or end (backward), query is in query string
GET  /status                  - returns middleware status (version, number of generations indexed)
```
(more to come)

## Transaction querying

### Scope

Scope specifies the time period to look for transactions matching the criteria, as well as direction:

- forward   - from beginning (genesis) to the end
- backward  - from end (top of chain) to the beginning
- gen/A-B   - from generation A to B (forward if A < B, backward otherwise)
- txi/A-B   - from transaction index A to B (forward if A < B, backward otherwise)

### Query parameters

Querying for transactions via `txs` endpoint supports 3 kinds of parameters specifying which transactions should be part of the reply:

- types
- generic ids
- transaction fields

Pagination supported via specifying of 2 parameters:

- limit
- page

----

#### Types

Types of transactions in the resulting set can be constrained by providing `type` and/or `type_group` parameter.
The query allows providing of multiple type & type_group parameters - they form a union of admissible types.
(In the other words - they are combined with `OR`.)

##### Supported types

* channel_close_mutual, channel_close_solo, channel_create, channel_deposit, channel_force_progress, channel_offchain, channel_settle, channel_slash, channel_snapshot_solo, channel_withdraw
* contract_call, contract_create
* ga_attach, ga_meta
* name_claim, name_preclaim, name_revoke, name_transfer, name_update
* oracle_extend, oracle_query, oracle_register, oracle_response
* paying_for
* spend

##### Supported type groups

Type groups for the transactions listed above are:

* channel
* contract
* ga
* name
* oracle
* paying
* spend

###### Examples

`type` parameter:
```
$ curl -s "http://localhost:4000/txs/forward?type=channel_create&limit=1" | jq '.'
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
        "channel_id": "ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD",
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
  "next": "txs/gen/0-265258?limit=1&page=2&type=channel_create"
}
```

`type_group` parameter:
```
$ curl -s "http://localhost:4000/txs/forward?type_group=oracle&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2G7DgcE1f9QJQNkYnLyTYTq4vjR47G4qUQHkwkXpNiT2J6hm5T",
      "block_height": 4165,
      "hash": "th_iECkSToLNWJ77Fiehi39zxJwLjPfstsAtYFC8rbCsEStEy1xv",
      "micro_index": 0,
      "micro_time": 1544106799973,
      "signatures": [
        "sg_XoYmhU7J6XzJazUvo48ijUKRj5DweV8rBuwBwgdZUiUEeYLe1h4pdJ7jbBWGHC8M7diMA2AFrH1AL739XNChX4wrH58Ng"
      ],
      "tx": {
        "abi_version": 0,
        "account_id": "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT",
        "fee": 20000,
        "nonce": 1,
        "oracle_id": "ok_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT",
        "oracle_ttl": {
          "type": "delta",
          "value": 1234
        },
        "query_fee": 20000,
        "query_format": "the query spec",
        "response_format": "the response spec",
        "type": "OracleRegisterTx",
        "version": 1
      },
      "tx_index": 8891
    }
  ],
  "next": "txs/gen/0-265260?limit=1&page=2&type_group=oracle"
}
```

----

#### Generic IDs

Generic ids allow selecting of transactions related to the provided id in `any` way.

With generic ids, it is possible to select also `create`/`register` transactions of particular Aeternity object (like contract, channel or oracle), despite the fact that these transactions don't have the ID of the created object among its transaction fields.

##### Supported generic IDs

- account
- contract
- channel
- oracle

(todo: name)

###### Examples

```
$ curl -s "http://localhost:4000/txs/forward?contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_ZwPrtCMWMPF5e4RLoaY8cb6HUGadSKknpy5gp8nrDes3eSKyZ",
      "block_height": 218938,
      "hash": "th_6memqAr5S3UQp1pc4FWXT8xUotfdrdUFgBd8VPmjM2ZRuojTF",
      "micro_index": 2,
      "micro_time": 1582898946277,
      "signatures": [
        "sg_LiNE1DtiFkUH19WtJ1p9tX9Zy9fuGaW3bAop1mLCe5jJktQ3XiAu2Bop6JPBrkHyi1eQ2xCyPXQxZmiyqroMwaL7BrqWN"
      ],
      "tx": {
        "abi_version": 3,
        "amount": 0,
        "call_data": "cb_KxFE1kQfK58CoImYHijBOQaROWmeJkniQvuQjKtkbE5UZnXQ+sB9eLb1nwCgkRvEABX1lZmfsIGIeFuXiHMZfg6eGt4RXdqdu+P8EZ1cfiCj",
        "code": "cb_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",
        "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "deposit": 0,
        "fee": 116060000000000,
        "gas": 1000000,
        "gas_price": 1000000000,
        "nonce": 2,
        "owner_id": "ak_26ubrEL8sBqYNp4kvKb1t4Cg7XsCciYq4HdznrvfUkW359gf17",
        "type": "ContractCreateTx",
        "version": 1,
        "vm_version": 5
      },
      "tx_index": 8392766
    },
    {
      "block_hash": "mh_233z34seMczJE7XtGLJN6ZrvJG9eQXG6fdTFymyzYyUyQbt2tY",
      "block_height": 218968,
      "hash": "th_2JLGkWhXbEQxMuEYTxazPurKiwGvo5R6vgqjSBw3R8z9F6b4rv",
      "micro_index": 1,
      "micro_time": 1582904578154,
      "signatures": [
        "sg_HKk9C1vCuHcZRj9zAdh2WvjvwVJwzNkXgPLsqy2SdR3L3hNkc1oMHjNnQxB558mdRWNPP711DMun3KEy9ZYyvo2QgR8B"
      ],
      "tx": {
        "arguments": [
          {
            "type": "string",
            "value": "https://github.com/thepiwo"
          },
          {
            "type": "string",
            "value": "Cool projects!"
          }
        ],
        "function": "tip",
        "result": {
          "type": "unit",
          "value": ""
        },
        "abi_version": 3,
        "amount": 1e+16,
        "call_data": "cb_KxHt0mtGK2lodHRwczovL2dpdGh1Yi5jb20vdGhlcGl3bzlDb29sIHByb2plY3RzIZ01af4=",
        "caller_id": "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2",
        "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "fee": 182980000000000,
        "gas": 1579000,
        "gas_price": 1000000000,
        "gas_used": 3600,
        "log": [
          {
            "address": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
            "data": "cb_aHR0cHM6Ly9naXRodWIuY29tL3RoZXBpd2+QKOcm",
            "topics": [
              8.317242847728886e+76,
              3.204945213498395e+76,
              1e+16
            ]
          }
        ],
        "nonce": 80,
        "return_type": "ok",
        "type": "ContractCallTx",
        "version": 1
      },
      "tx_index": 8395071
    }
  ],
  "next": "txs/gen/0-265268?contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2&page=2"
}
```

```
$ curl -s "http://localhost:4000/txs/forward?oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2kSWEwFPPMXSjCx3r1nxi3vnpnXAYB7TEVZuEJsSkGjnsewTBF",
      "block_height": 34421,
      "hash": "th_MRDMpanm3UqgNtAtpEsM59LkyX3TL2wXgeXnx4T9Yn8w1f9L1",
      "micro_index": 0,
      "micro_time": 1549551115213,
      "signatures": [
        "sg_LdVk6F8PPMDPW9ZGkAX653GgaSpjRrfgRByKGAjvxUaBAqjgdG7t6NyLs5UPYBWk7xVEfXgyTNgyrjpvfqaFz7DA9L9ZV"
      ],
      "tx": {
        "abi_version": 0,
        "account_id": "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
        "fee": 20000,
        "nonce": 18442,
        "oracle_id": "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
        "oracle_ttl": {
          "type": "delta",
          "value": 1000
        },
        "query_fee": 20000,
        "query_format": "string",
        "response_format": "int",
        "ttl": 50000,
        "type": "OracleRegisterTx",
        "version": 1
      },
      "tx_index": 600284
    }
  ],
  "next": "txs/gen/0-265268?limit=1&oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&page=2"
}
```

```
$ curl -s "http://localhost:4000/txs/forward?channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&limit=2" | jq '.'
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
        "channel_id": "ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD",
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
    },
    {
      "block_hash": "mh_joVBtAVakCpGWqesP4S8HpDTs6tUuwq2hjpGHwN4aGP1shfFx",
      "block_height": 14258,
      "hash": "th_meBfq6EWuUXExBRkbi618RVkQ8nFMz7uo26HkxFXwko9NjF9L",
      "micro_index": 0,
      "micro_time": 1545910910104,
      "signatures": [
        "sg_GnbScdeBzkXhj9DR1GQcb2LFxHmuL1eNYrScRCPVp2XKt26BoinsrAbdMBWZimqrY36sF5PzAiA4Vqfx6yfGtRtMGXPuQ",
        "sg_VoH1jw5de6wtpzdDsZnA1ATgqV22Rkq2YN2SsphiwqCbY9nipjm3CcwkbKWhAkrud6MnY9biJHVDAzu5UjMf8c691fEcA"
      ],
      "tx": {
        "amount": 10,
        "channel_id": "ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD",
        "fee": 17240,
        "nonce": 16,
        "round": 5,
        "state_hash": "st_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACr8s/aY",
        "to_id": "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS",
        "type": "ChannelWithdrawTx",
        "version": 1
      },
      "tx_index": 94616
    }
  ],
  "next": "txs/gen/0-265269?channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&limit=2&page=2"
}
```

----

#### Transaction fields

Every transaction record has one or more fields with identifier, represented by public key.
Middleware is indexing these fields and allows them to be used in the query.

##### Supported fields with provided transaction type

The syntax of the field with provided type is: `type`.`field` - for example: `spend.sender_id`

The fields for transaction types are:

- channel_close_mutual - channel_id, from_id
- channel_close_solo - channel_id, from_id
- channel_create - initiator_id, responder_id
- channel_deposit - channel_id, from_id
- channel_force_progress - channel_id, from_id
- channel_offchain - channel_id
- channel_settle - channel_id, from_id
- channel_slash - channel_id, from_id
- channel_snapshot_solo - channel_id, from_id
- channel_withdraw - channel_id, to_id
- contract_call - caller_id, contract_id
- contract_create - owner_id
- ga_attach - owner_id
- ga_meta - ga_id
- name_claim - account_id
- name_preclaim - account_id, commitment_id
- name_revoke - account_id, name_id
- name_transfer - account_id, name_id, recipient_id
- name_update - account_id, name_id
- oracle_extend - oracle_id
- oracle_query - oracle_id, sender_id
- oracle_register - account_id
- oracle_response - oracle_id
- paying_for - payer_id
- spend - recipient_id, sender_id

##### Supported freestanding fields

In case a freestanding field (without transaction type) is part of the query, it deduces the admissible set of types to those which have this field.

The types for freestanding fields are:

- account_id - name_claim, name_preclaim, name_revoke, name_transfer, name_update, oracle_register
- caller_id - contract_call
- channel_id - channel_close_mutual, channel_close_solo, channel_deposit, channel_force_progress, channel_offchain, channel_settle, channel_slash, channel_snapshot_solo, channel_withdraw
- commitment_id - name_preclaim
- contract_id - contract_call
- from_id - channel_close_mutual, channel_close_solo, channel_deposit, channel_force_progress, channel_settle, channel_slash, channel_snapshot_solo
- ga_id - ga_meta
- initiator_id - channel_create
- name_id - name_revoke, name_transfer, name_update
- oracle_id - oracle_extend, oracle_query, oracle_response
- owner_id - contract_create, ga_attach
- payer_id - paying_for
- recipient_id - name_transfer, spend
- responder_id - channel_create
- sender_id - oracle_query, spend
- to_id - channel_withdraw

###### Examples

with provided transaction type (`name_transfer`):
```
$ curl -s "http://localhost:4000/txs/forward?name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2aLMAszzEf3ZS2Xkn8JRrzU4ogWBzxiDYYFqmUKz1r3XJ7nvEF",
      "block_height": 262368,
      "hash": "th_ssPMQvMPgRgUdbYJXzwxCBugz9J8fgP37MoVdqiBHR71Cm2nM",
      "micro_index": 80,
      "micro_time": 1590759423839,
      "signatures": [
        "sg_DBJnw22QJ7gcfhMMvYdkDqgf3LstHLivZjVdPSXz2LuUHedhQwfrpEEdwvebcqwxdNsrRv7FnzbG8f7oEex3muv7ZayZ5"
      ],
      "tx": {
        "account_id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
        "fee": 17380000000000,
        "name_id": "nm_2t5eU4gLBmMaw4xn3Xb6LZwoJjB5qh6YxT39jKyCq4dvVh8nwf",
        "nonce": 190,
        "recipient_id": "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF",
        "ttl": 262868,
        "type": "NameTransferTx",
        "version": 1
      },
      "tx_index": 11700056
    }
  ],
  "next": "txs/gen/0-265290?limit=1&name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&page=2"
}
```

freestanding field `from_id`, and via `jq` extracting only tx_index and transaction type:
```
curl -s "http://localhost:4000/txs/backward?from_id=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&limit=5" | jq '.data | .[] | [.tx_index, .tx.type]'
[
  98535,
  "ChannelForceProgressTx"
]
[
  96518,
  "ChannelSettleTx"
]
[
  96514,
  "ChannelSlashTx"
]
[
  94618,
  "ChannelSnapshotSoloTx"
]
[
  94617,
  "ChannelDepositTx"
]
```

----

#### Pagination

Middleware supports 2 optional query parameters:

- limit - limits max number of transactions in the reply (in range 1..1000, default is 10)
- page - tells which page to return (default is 1)

The client can set `limit` explicitly if he wishes to receive different number of transactions in the reply than 10.

The main function of `page` parameter is to support fetching another page from the reply set.
Middleware has DOS protection, by only allowing to ask for subsequent page.
Asking for arbitrary page, without requesting a previous one before results in error:

```
$ curl -s "http://localhost:4000/txs/forward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&page=10" | jq '.'
{
  "error": "random access not supported"
}
```

The `txs` endpoint returns json in shape `{"data": [...transactions...], "next": continuation-URL or null}`

The `continuation-URL`, when concatenated with host, can be used to retrieve next page of results.

##### Examples

getting the first transaction:
```
$ curl -s "http://localhost:4000/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2Rkmk15VeTVWTHt9bVBFcQRuvseKCkuHpm1RexsMcpAdZpFCLx",
      "block_height": 77216,
      "hash": "th_MutYY63TMfYQ7z4rWrQd8WGJqszz1h3FdAGHYLVYJBquHoG2V",
      "micro_index": 0,
      "micro_time": 1557275476873,
      "signatures": [
        "sg_SKC9yVm59qNh3HrpRdqfbkYnoH1ksypECnPxe67iuPadF3KN7HjR4D7qs4gYkeAhbgno2yUjHfZMcTxrF6CKFZQPaGfdq"
      ],
      "tx": {
        "amount": 1e+18,
        "fee": 16840000000000,
        "nonce": 7,
        "payload": "ba_Xfbg4g==",
        "recipient_id": "ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD",
        "sender_id": "ak_2cLJfLQPhkTiz7RCVQ9ii8mVPJu8gHLy6qpafmTcHYrFYWBHCG",
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 1776073
    }
  ],
  "next": "txs/gen/0-265354?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1&page=2"
}
```

getting the next transaction by prepending host (http://localhost:4000) to the continuation-URL from last request:
```
$ curl -s "http://localhost:4000/txs/gen/0-265354?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1&page=2" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_SDfdhTd3zfTpAqHMUJsX8RjAm6QyrZYgtqNf3y6EdMMSppEgd",
      "block_height": 77865,
      "hash": "th_2RfB4NrPNyAr8gkm5vTQimVo6uBcZMQfmqdY8LZkuRJfhcs3HA",
      "micro_index": 0,
      "micro_time": 1557391780018,
      "signatures": [
        "sg_XjVTnUbvytX3pAbQQvwYFYXETCqDKzyen7kXqoEqRm5hr6m72k3RzKBHP4GWTHup51ZnxQuDf8R8Rxu5fUwAQGeQMHmh1"
      ],
      "tx": {
        "amount": 1e+18,
        "fee": 16840000000000,
        "nonce": 6,
        "payload": "ba_Xfbg4g==",
        "recipient_id": "ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD",
        "sender_id": "ak_2iK7D3t5xyN8GHxQktvBnfoC3tpq1eVMzTpABQY72FXRfg3HMW",
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 1779354
    }
  ],
  "next": "txs/gen/0-265354?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1&page=3"
}
```

Once there are no more transactions for a query, the `next` key is set to `null`.

----

### Mixing of query parameters

The query string can mix types, global ids and transaction fields.

The resulting set of transactions must meet all constraints specified by parameters denoting ID (global ids and transaction fields) - the parameters are combined with `AND`.

If `type` or `type_group` is provided, the transaction in the result set must be of some type specified by these parameters.

#### Examples

transactions where each transaction contains both accounts, no matter at which field:
```
$ curl -s "http://localhost:4000/txs/backward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_vCizDmxFrwMFCjBFDWfe8husZ4i8d7K2hFKfmQHhau3DkK9Ka",
      "block_height": 68234,
      "hash": "th_2HvqS7RjoWvBFMGr6WsUsXRhDEcfs3DotZXFm5rRNg7TVZUmnu",
      "micro_index": 0,
      "micro_time": 1555651193447,
      "signatures": [
        "sg_Rimi7QJoHfuFTG79iuZ92GTrmzPcjBxRDe4DniXX9SveAQWcZx9D3FMHUhc7fzfSgJ8vcykGrGpdUXtM3gkFM1pMy4AVL"
      ],
      "tx": {
        "amount": 1,
        "fee": 30000000000000,
        "nonce": 19223,
        "payload": "ba_dGVzdJVNWkk=",
        "recipient_id": "ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD",
        "sender_id": "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
        "ttl": 70000,
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 1747960
    }
  ],
  "next": "txs/gen/265300-0?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1&page=2"
}
```

spend transactions between sender and recipient (transaction type = spend is deduced from the fields):
```
$ curl -s "http://localhost:4000/txs/forward?sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_88NN1Y5rmofQ5SUkQNcuBnLMyQucdrCXXcqBduYjLygDmSuSz",
      "block_height": 172,
      "hash": "th_LnKAy1SDEwQjn9kvVmZ8woCExEX7g29UBvZthWnugKAF2ZBhf",
      "micro_index": 1,
      "micro_time": 1543404316091,
      "signatures": [
        "sg_7wbXjsJLYy3gxGpLsi62s9j7nd4Qm3uppPFsNXLw7WdqZE6b1mPyUqkiMvDTJMD3zQCYy2BNgzpdyLAZJuNmkKKhmFUL3"
      ],
      "tx": {
        "amount": 1000000,
        "fee": 20000,
        "nonce": 10,
        "payload": "ba_SGFucyBkb25hdGVzs/BHFA==",
        "recipient_id": "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2",
        "sender_id": "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
        "type": "SpendTx",
        "version": 1
      },
      "tx_index": 9
    }
  ],
  "next": "txs/gen/0-265304?limit=1&page=2&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
}
```

name related transactions for account:
```
$ curl -s "http://localhost:4000/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&type_group=name" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_JRADbFAfMf4JJApALLc3JuJgmQtRsQ91WHQvyGZzGJiCuLBFV",
      "block_height": 141695,
      "hash": "th_vNPVyhuUTWkdvU9hTC6vRK52Hevt5Lbv3ZjVV67KoghE1Vake",
      "micro_index": 17,
      "micro_time": 1568931464420,
      "signatures": [
        "sg_C81dBwSTehaPDuz23PDAeZZAgTQYeTGcpYXabkTQiQa7YBzvwwK9us7dxSd6FsqZ2wpzmsM72QYwoUJzKtsY75BG8Eu9i"
      ],
      "tx": {
        "account_id": "ak_AiQGnvEgsbLQixVJABpTc9h7hXtP4Lt3sorCa9FbtvYfiBH6a",
        "fee": 17300000000000,
        "name_id": "nm_2fzt9CmGxe1GgKs42xM95h8nvgXqTECCKqjSZQinQUiwBooGid",
        "nonce": 6,
        "recipient_id": "ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD",
        "type": "NameTransferTx",
        "version": 1
      },
      "tx_index": 3550045
    }
  ],
  "next": null
}
```

----

## Querying from Elixir's shell

One of the goals of the new middleware was to have the querying ability available in the shell, as a function for easy integration with other parts if needed.

### MAP function

The HTTP request is translated to the call to the query function called `map`, in `AeMdw.Db.Stream` module:

```
map(scope),
map(scope, mapper),
map(scope, mapper, query),
map(scope, mapper, query, prefer_direction),
```

The result of `map` function is a `stream yielding transactions on demand`, not the transctions themselves.

To get the transactions from this stream, it must be consumed with one of:

- `Enum.to_list/1`               - get all transaction
- `Enum.take/2`                  - get chunk of provided size
- `StreamSplit.take_and_drop/2`  - get chunk of provided size AND stream generating the rest of the result set

### Arguments

#### Scope

- `:forward`     - from beginning (genesis) to the end
- `:backward`    - from end (top of chain) to the beginning
- `{:gen, a..b}` - from generation a to b (forward if a < b, backward otherwise)
- `{:txi, a..b}` - from transaction index a to b (forward if a < b, backward otherwise)

#### Mapper

- `:txi`  - extract just transaction index from transactions in result set
- `:raw`  - translate Erlang transaction record into map, enrich the map with additional data, don't encode IDs
- `:json` - translate Erlang transaction record into map, enrich the map with additional data, encode IDs for JSON compatibility

#### Query

Query is a key value list of constraints, as described above:

- `:type`, `:type_group`
- `:account`, `:contract`, `:channel`, `:oracle` (todo: `:name`)
- fields as described above:
  - freestanding: for example: `:sender_id`, `:from_id`, `:contract_id`, ...
  - with type: for example: `:'spend.sender_id'`

As with query string, providing multiple type, or global ids or fields is supported.
Type constraints combine with `OR`, ids and fields combine with `AND`.

#### Prefer Order

Either `:forward` or `:backward`.

This optional parameter is rarely needed.
It's purpose is to force direction of iteration, overriding derived direction from `scope`.

### Examples

For convenience, we alias `AeMdw.Db.Stream` module:
```
alias AeMdw.Db.Stream, as: DBS
```

Binding a stream to a "variable":
```
iex(aeternity@localhost)47> s = DBS.map(:forward, :raw)
#Function<55.119101820/2 in Stream.resource/3>
```

Get first transaction (genesis):
(note that the mapper (when creating the stream) was `:raw` - it affects the format of the output)
```
iex(aeternity@localhost)48> s |> Enum.take(1)
[
  %{
    block_hash: <<119, 150, 138, 100, 62, 23, 145, 61, 204, 61, 156, 228, 43,
      173, 81, 168, 211, 94, 220, 238, 183, 91, 245, 112, 230, 47, 52, 44, 191,
      34, 49, 235>>,
    block_height: 1,
    hash: <<164, 38, 1, 147, 61, 29, 56, 40, 111, 178, 197, 124, 115, 149, 188,
      19, 47, 119, 120, 111, 53, 92, 10, 1, 24, 116, 100, 201, 234, 146, 180,
      157>>,
    micro_index: 0,
    micro_time: 1543375246712,
    signatures: [
      <<112, 133, 201, 51, 75, 65, 83, 138, 79, 82, 251, 174, 141, 218, 143, 44,
        179, 103, 222, 101, 139, 79, 218, 201, 230, 109, 149, 134, 13, 231, 40,
        146, 52, 83, 160, 139, 55, 214, 96, 76, 174, 136, ...>>
    ],
    tx: %{
      amount: 150425,
      fee: 101014,
      nonce: 1,
      payload: "790921-801018",
      recipient_id: {:id, :account,
       <<144, 125, 123, 13, 183, 6, 234, 74, 192, 116, 177, 35, 130, 58, 45,
         133, 185, 14, 29, 143, 113, 100, 77, 100, 127, 133, 98, 225, 46, 110,
         14, 75>>},
      sender_id: {:id, :account,
       <<144, 125, 123, 13, 183, 6, 234, 74, 192, 116, 177, 35, 130, 58, 45,
         133, 185, 14, 29, 143, 113, 100, 77, 100, 127, 133, 98, 225, 46, 110,
         14, 75>>},
      ttl: 0,
      type: :spend_tx
    },
    tx_index: 0
  }
]
```

Get transaction indices (note `txi` mapper) of last 2 transactions of Superhero contract:
```
iex(aeternity@localhost)53> DBS.map(:backward, :txi, contract: "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z") |> Enum.take(2)
[11943361, 11942780]
```

Get latest contract creation transaction for account, as JSON compatible map:
```
iex(aeternity@localhost)62> DBS.map(:backward, :json, account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR", type: :contract_create) |> Enum.take(1)
[
  %{
    "block_hash" => "mh_2vf1rUd9eGEK3dErZzVPD3DiAdb2tXgqqCpi5omvvZwPD3KYxh",
    "block_height" => 42860,
    "hash" => "th_2Turq396oFwxMP9R2DGVbhrRx2pcm2TDvwZYHLRxiLkpDzNFt2",
    "micro_index" => 217,
    "micro_time" => 1551072615670,
    "signatures" => ["sg_2XUcjG9Pc5RxrG7pa84LeJsC3nNUEBrJiJAL82GyFKt5pNrGpaPvbyScB7NMssDEpPFTh3fjP3VQMZzxfZdkYExegHmHB"],
    "tx" => %{
      "abi_version" => 1,
      "amount" => 1,
      "call_data" => "cb_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCt9bwh/i9hv+GKi/ANbdv90gR3IIMG58OESu0Pr20OJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAW845bQ==",
      "code" => "cb_+SquRgGgkvoZApwagOEb0ECJTcjFb4LREWQmThWornrMZiqU7IL5F1/4zKAkheOHvLYGQ5t7ogUCl4inPWJBXgCJKqHCyoOZqXs1hYZzeW1ib2y4YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//////////////////////////////////////////7hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAfkB9KAv+IVN5raUdqtpihVQ7AOqCYLAZJbFXpmUWDBtDD6aI410cmFuc2Zlcl9mcm9tuQGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWD//////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+NKgMo8xCDuRufaoEFAEhHE22v57oLigoUKF/hk+BZ0c6q2MdG90YWxfc3VwcGx5uGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD//////////////////////////////////////////+4QAAA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" <> ...,
      "contract_id" => "ct_2aCcWJst7rF6pXd2Sh99QTaqAK2wRa2t1pdsFNn5qVucSfvGmF",
      "deposit" => 4,
      "fee" => 1875780,
      "gas" => 1579000,
      "gas_price" => 1,
      "nonce" => 18558,
      "owner_id" => "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      "type" => "ContractCreateTx",
      "version" => 1,
      "vm_version" => 1
    },
    "tx_index" => 839835
  }
]
```

#### Continuation example

Gets first `name_transfer` transaction with provided `recipient_id`, and different account in any other field, AND also bind the continuation to variable `cont`:
```
{_, cont} = DBS.map(:forward, :json, 'name_transfer.recipient_id': "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF", account: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN") |> StreamSplit.take_and_drop(1)
{[
   %{
     "block_hash" => "mh_L5MkbeEnyJWdxbvQQS3Q2VXe3WVed7phtJPNirGeG3H4W89Tn",
     "block_height" => 263155,
     "hash" => "th_mXbNbgaS8w3wFRd3tHS2mHGVxAnL9jX7SsMN76JqKHHmcrMig",
     "micro_index" => 0,
     "micro_time" => 1590901848030,
     "signatures" => ["sg_8z5HdmBQm5ew51geWDtz3eBXZ1HSc87aPNFJDwEfeKJkBUisMQEQuVMwXpRWCYdbm7sT1DAtLsUAxr6uLPyHmKtou2efH"],
     "tx" => %{
       "account_id" => "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
       "fee" => 17360000000000,
       "name_id" => "nm_2t5eU4gLBmMaw4xn3Xb6LZwoJjB5qh6YxT39jKyCq4dvVh8nwf",
       "nonce" => 1,
       "recipient_id" => "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF",
       "ttl" => 263654,
       "type" => "NameTransferTx",
       "version" => 1
     },
     "tx_index" => 11758274
   }
 ],
 %StreamSplit{
   continuation: #Function<23.119101820/1 in Stream.do_resource/5>,
   stream: #Function<55.119101820/2 in Stream.resource/3>
 }}
```

Get subsequent transaction, using the continuation:
```
iex(aeternity@localhost)69> cont |> Enum.take(1)
[
  %{
    "block_hash" => "mh_wybuH39ALrhL3N1MzRuCC4rA8BmWKtsbVbcVu6aCyzSRrvu8s",
    "block_height" => 263155,
    "hash" => "th_HZgLPr98rabb5fTha2cAmyQiGcREA4DoZpU2VRt8nhXDJDuXe",
    "micro_index" => 2,
    "micro_time" => 1590901854030,
    "signatures" => ["sg_XxqhRsKyr2a4AqdHZESEVf7SoGFAuvSSbaFt6pprh3376FvvztNXKCR2qmGPfT2SFvRsaFgfmujrtbQKPeGgQnGWvF7mJ"],
    "tx" => %{
      "account_id" => "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
      "fee" => 17360000000000,
      "name_id" => "nm_nCeYsPNhTb4TqEdpAWTMaWMpuJQdA9YfTwCPTGRLjo8ETJh2C",
      "nonce" => 2,
      "recipient_id" => "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF",
      "ttl" => 263655,
      "type" => "NameTransferTx",
      "version" => 1
    },
    "tx_index" => 11758279
  }
]
```

The `cont` above could be also passed as parameter to another invocation of `StreamSplit.take_and_drop/2` - producing next result and another continuation.

This design decouples query construction and actual consumption of the result set.

----

## Other transaction related endpoints

### TX - get transaction by hash

```
$ curl -s "http://localhost:4000/tx/th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq" | jq '.'
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

### TXI - get transaction by index

```
$ curl -s "http://localhost:4000/txi/10000000" | jq '.'
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

### TXS/COUNT endpoint

#### All transactions

```
$ curl -s "http://localhost:4000/txs/count" | jq '.'
11921825
```

#### Transactions by type/field for ID

```
$ curl -s "http://localhost:4000/txs/count/ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR" | jq '.'
{
  "channel_create_tx": {
    "responder_id": 74
  },
  "contract_call_tx": {
    "caller_id": 69
  },
  "contract_create_tx": {
    "owner_id": 3
  },
  "name_claim_tx": {
    "account_id": 7
  },
  "name_preclaim_tx": {
    "account_id": 26
  },
  "name_revoke_tx": {
    "account_id": 1
  },
  "name_transfer_tx": {
    "account_id": 1
  },
  "name_update_tx": {
    "account_id": 40
  },
  "oracle_extend_tx": {
    "oracle_id": 4
  },
  "oracle_query_tx": {
    "oracle_id": 16,
    "sender_id": 556
  },
  "oracle_register_tx": {
    "account_id": 6
  },
  "oracle_response_tx": {
    "oracle_id": 6
  },
  "spend_tx": {
    "recipient_id": 8,
    "sender_id": 18505
  }
}
```

## Naming System

There are several endpoints for querying of the Naming System.

### Name Resolution

```
$ curl -s "http://localhost:4000/name/bear.test" | jq '.'
{
  "active": false,
  "info": {
    "active_from": 85624,              # block height
    "auction_timeout": 0,              # in blocks
    "claims": [
      2101866                          # transaction index
    ],
    "expire_height": 135638,           # block height
    "ownership": {
      "current": "ak_2CXSVZqVaGuZsmcRs3CN6wb2b9GKtf7Arwej7ahbeAQ1S8qkmM", # from transfer tx
      "original": "ak_2CXSVZqVaGuZsmcRs3CN6wb2b9GKtf7Arwej7ahbeAQ1S8qkmM" # claimant
    },
    "pointers": {
      "account_pubkey": "ak_pMwUuWtqDoPxVtyAmWT45JvbCF2pGTmbCMB4U5yQHi37XF9is"
    },
    "revoke": null,                    # null OR transaction index
    "transfers": [],                   # transaction indices
    "updates": [
      2103935                          # transaction index
    ]
  },
  "name": "bear.test",
  "previous": [                        # previous epochs of the same name
    {
      "active_from": 4054,
      "auction_timeout": 0,
      "claims": [
        5800
      ],
      "expire_height": 40054,
      "ownership": {
        "current": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
        "original": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"
      },
      "pointers": {
        "account_pubkey": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"
      },
      "revoke": null,
      "transfers": [],
      "updates": [
        5801
      ]
    }
  ],
  "status": "name"
}
```

It's possible to use encoded hash as well:

```
$ curl -s "http://localhost:4000/name/nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj" | jq '.'
{
  "active": true,
  "info": {
    "active_from": 279555,
    "auction_timeout": 0,
    "claims": [
      12942484
    ],
    "expire_height": 329558,
    "ownership": {
      "current": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
      "original": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
    },
    "pointers": {
      "account_pubkey": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
    },
    "revoke": null,
    "transfers": [],
    "updates": [
      12942695
    ]
  },
  "name": "wwwbeaconoidcom.chain",
  "previous": [],
  "status": "name"
}
```

If there's no suffix (`.chain` or `.test`), `.chain` is added by default:
```
$ curl -s "http://localhost:4000/name/aeternity" | jq '.'
{
  "active": true,
  "info": {
    "active_from": 162197,
    "auction_timeout": 480,
    "claims": [
      4712046,
      4711222,
      4708228,
      4693879,
      4693568,
      4678533
    ],
    "expire_height": 304439,
    "ownership": {
      "current": "ak_2rGuHcjycoZgzhAY3Jexo6e1scj3JRCZu2gkrSxGEMf2SktE3A",
      "original": "ak_2ruXgsLy9jMwEqsgyQgEsxw8chYDfv2QyBfCsR6qtpQYkektWB"
    },
    "pointers": {
      "account_pubkey": "ak_2cJokSy6YHfoE9zuXMygYPkGb1NkrHsXqRUAAj3Y8jD7LdfnU7"
    },
    "revoke": null,
    "transfers": [
      8778162
    ],
    "updates": [
      11110443,
      10074212,
      10074008,
      8322927,
      7794392
    ]
  },
  "name": "aeternity.chain",
  "previous": [],
  "status": "name"
}
```

If the name is currently in auction, the reply has different shape:
```
$ curl -s "http://localhost:4000/name/help" | jq '.'
{
  "active": false,
  "info": {
    "auction_end": 302041,                   # block height
    "bids": [
      12433889                               # transaction index
    ],
    "last_bid": {
      "block_hash": "mh_2vrYDKt2L1uBN7f8HEFSVUViUrxjNFASQcaHdrrPgdzh7MER2d",
      "block_height": 272281,
      "hash": "th_26BczfSQhgnVv1XQBaVNM3PzMuwLPLwR9WZ1qgthcFYJztLkdW",
      "micro_index": 0,
      "micro_time": 1592546912379,
      "signatures": [
        "sg_ZsdWenUVDvSW7xQCCfd4SxG8UjbKTWpZimsotmcv8q8fdqdPb7qno4BRLDGhtHNDN6fNJBZSk6M4VYuycLdWYXGavmps6"
      ],
      "tx": {
        "account_id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
        "fee": 17100000000000,
        "name": "help.chain",
        "name_fee": 141358245000000000000,
        "name_id": "nm_2WoR2PCFXeLiLQH8C7GVbGpU57qDBqkQbPvaML8w3ijMQiei7E",
        "name_salt": 5.50894365698189e+76,
        "nonce": 254,
        "ttl": 272779,
        "type": "NameClaimTx",
        "version": 2
      },
      "tx_index": 12433889
    }
  },
  "name": "help.chain",
  "previous": [],
  "status": "auction"
}
```

### Listing names

There are 4 paginable endpoints for listing names:

- /names - for listing ALL names (`active` and `inactive`), except those in auction
- /names/inactive - for listing `inactive` names (expired or revoked)
- /names/active - for listing `active` names
- /names/auctions - for listing `auctions`

They support ordering via parameters `by` (with options `expiration` and `name`), and `direction` (with options `forward` and `backward`).

Without these parameters, the endpoints return results ordered as if `by=expiration` and `direction=backward` were provided.

The parameter `limit` (by default = 10) is optional, and limits the number of elements in the response.


#### All names

```
$ curl -s "http://localhost:4000/names?limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "info": {
        "active_from": 205194,
        "auction_timeout": 14880,
        "claims": [
          6264107
        ],
        "expire_height": 349080,
        "ownership": {
          "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
          "original": "ak_pMwUuWtqDoPxVtyAmWT45JvbCF2pGTmbCMB4U5yQHi37XF9is"
        },
        "pointers": {
          "account_pubkey": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
        },
        "revoke": null,
        "transfers": [
          11861475,
          11860109
        ],
        "updates": [
          14543330,
          14505538,
          14467888,
          14426800,
          14390282,
          14353967,
          14317741,
          14270055,
          14233470,
          14194346,
          14155286,
          14116038,
          14080116,
          14044009,
          14003639,
          13964444,
          13925716,
          13885179,
          13849484,
          13726977,
          13689551,
          13650653,
          13617597,
          13582977,
          13546321,
          13513872,
          13475401,
          13118526,
          13118504,
          12757704,
          12757665,
          12757629,
          12757597,
          12757567,
          12757542,
          12757511,
          12432470,
          12432445,
          12077800,
          12077767,
          11096410,
          8025749
        ]
      },
      "name": "jieyi.chain",
      "previous": [],
      "status": "name"
    },
    {
      "active": true,
      "info": {
        "active_from": 253179,
        "auction_timeout": 480,
        "claims": [
          10982214
        ],
        "expire_height": 349071,
        "ownership": {
          "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
          "original": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx"
        },
        "pointers": {
          "account_pubkey": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
        },
        "revoke": null,
        "transfers": [
          11802923,
          11802444,
          11798902
        ],
        "updates": [
          14542592,
          14504810,
          14467150,
          14425332,
          14388049,
          14351750,
          14316275,
          14268586,
          14232001,
          14191428,
          14153084,
          14113833,
          14078596,
          14043263,
          14002870,
          13963698,
          13924995,
          13884427,
          13848748,
          13724781,
          13688047,
          13648398,
          13615903,
          13581447,
          13545563,
          13513208,
          13474497,
          13117722,
          13117694,
          13117669,
          12756905,
          12431769,
          12431744,
          12431718,
          12077315,
          12077262,
          11433982
        ]
      },
      "name": "helloword.chain",
      "previous": [],
      "status": "name"
    }
  ],
  "next": "names/gen/299097-0?limit=2&page=2"
}
```

#### Inactive names

For demonstration, they are ordered by `expiration` with direction `forward`.
This means, we list from oldest to newest expired names.

```
$ curl -s "http://localhost:4000/names/inactive?by=expiration&direction=forward&limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "info": {
        "active_from": 6089,
        "auction_timeout": 0,
        "claims": [
          12356
        ],
        "expire_height": 16090,
        "ownership": {
          "current": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7",
          "original": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
        },
        "pointers": {
          "account_pubkey": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          12547
        ]
      },
      "name": "philippsdk.test",
      "previous": [],
      "status": "name"
    },
    {
      "active": false,
      "info": {
        "active_from": 6094,
        "auction_timeout": 0,
        "claims": [
          13113
        ],
        "expire_height": 16094,
        "ownership": {
          "current": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7",
          "original": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
        },
        "pointers": {
          "account_pubkey": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          13114
        ]
      },
      "name": "philippsdk2.test",
      "previous": [],
      "status": "name"
    }
  ],
  "next": "names/inactive/gen/299100-0?by=expiration&direction=forward&limit=2&page=2"
}
```

#### Active names

For demonstration, they are sorted by `name`.
Without `direction` parameter, default value `backward` is used.

```
$ curl -s "http://localhost:4000/names/active?by=name&limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "info": {
        "active_from": 162213,
        "auction_timeout": 0,
        "claims": [
          4748820
        ],
        "expire_height": 309542,
        "ownership": {
          "current": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8",
          "original": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8"
        },
        "pointers": {
          "account_pubkey": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          11490573,
          8946568,
          5770445,
          5561653,
          5561576,
          4776331,
          4771609,
          4748827
        ]
      },
      "name": "0000000000000.chain",
      "previous": [],
      "status": "name"
    },
    {
      "active": true,
      "info": {
        "active_from": 183423,
        "auction_timeout": 480,
        "claims": [
          5721301
        ],
        "expire_height": 336933,
        "ownership": {
          "current": "ak_id5HJww6GzFBuFeVGX1NNM66fuzuyfvnCQgZmRxzdSnW8WRcv",
          "original": "ak_id5HJww6GzFBuFeVGX1NNM66fuzuyfvnCQgZmRxzdSnW8WRcv"
        },
        "pointers": {
          "account_pubkey": "ak_VLkEyJBmvaf6XnqLdknjj7ZMN58G5x1eJhNUkLxPFGmg9JAaJ"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          13597701,
          12338867,
          11556782,
          11556781,
          10066616,
          10066605,
          9175096,
          8450457
        ]
      },
      "name": "0123456789.chain",
      "previous": [],
      "status": "name"
    }
  ],
  "next": "names/active/gen/299098-0?by=name&limit=2&page=2"
}
```

#### Auctions

Without ordering parameters, the first auction in reply set expires the latest.

```
$ curl -s "http://localhost:4000/names/auctions?limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "info": {
        "auction_end": 320279,
        "bids": [
          13863543
        ],
        "last_bid": {
          "block_hash": "mh_2hXMY6BJ49LAMKNFcADx4dPesYbcnJj7ac881ojrktUecHPiYf",
          "block_height": 290519,
          "hash": "th_2KNZfYmAFKyW3xhvfdWAjMc6R5FRy2nUjLtYUuQsQyxGJ84kGJ",
          "micro_index": 0,
          "micro_time": 1595846818606,
          "signatures": [
            "sg_XtQb143doXyS2tE8DNb2563Ukxy18aBbL9dd8iDxYNjUmZq2xywLp1qyiLancXjauRmYaQQz54aXKjevw21pGmZwv4gLA"
          ],
          "tx": {
            "account_id": "ak_pMwUuWtqDoPxVtyAmWT45JvbCF2pGTmbCMB4U5yQHi37XF9is",
            "fee": 16540000000000,
            "name": "ant.chain",
            "name_fee": 217830900000000000000,
            "name_id": "nm_2gck1wvusmLUH1pRJ6dUgHxuVBM5Nf75q64wZHB2TwadpHH6Xv",
            "name_salt": 8831319772225873,
            "nonce": 524,
            "type": "NameClaimTx",
            "version": 2
          },
          "tx_index": 13863543
        }
      },
      "name": "ant.chain",
      "previous": [],
      "status": "auction"
    },
    {
      "active": false,
      "info": {
        "auction_end": 316465,
        "bids": [
          13581110,
          12162548,
          10084274,
          10059350,
          7808796,
          7455148,
          5564748
        ],
        "last_bid": {
          "block_hash": "mh_CVYWyhvtQiqbYwRQYV7NPxknWqVTxoefyXz2X9R2kKGrx8vM2",
          "block_height": 286705,
          "hash": "th_2Us1TMbypBpnNZagh3hexbvL4KuQF89JV8sFf92RRChPiwTQBC",
          "micro_index": 102,
          "micro_time": 1595155581605,
          "signatures": [
            "sg_7pGmtgSMXLCa7YchSDFSeLVis9JYrAWKDgd4SPCnsNQQVFZhJKR4HyEentwZkKHT5GJN6L5VikwEsdkPNKDXD5xur6LiM"
          ],
          "tx": {
            "account_id": "ak_w9dCnphJRYxpjrPZSXUm8RPXAhFFdxyhqFGq1yPt23B4M8A1n",
            "fee": 16320000000000,
            "name": "5.chain",
            "name_fee": 8e+20,
            "name_id": "nm_2G8VVfnRqJjxcpNu8vbHJyaYhCoR9Gys42AvaEK3hMN8tfXCr6",
            "name_salt": 0,
            "nonce": 24,
            "type": "NameClaimTx",
            "version": 2
          },
          "tx_index": 13581110
        }
      },
      "name": "5.chain",
      "previous": [],
      "status": "auction"
    }
  ],
  "next": "names/auctions/gen/299100-0?limit=2&page=2"
}
```

To show auctions starting with the one expiring the earliest:

```
$ curl -s "http://localhost:4000/names/auctions?by=expiration&direction=forward&limit=2" | jq '.data [] .info.auction_end'
300490
300636
```

Or, ordered by name, from the begining:

```
$ curl -s "http://localhost:4000/names/auctions?by=name&direction=forward&limit=1000" | jq '.data [] .name'
"0.chain"
"5.chain"
"6.chain"
"8.chain"
"AEStudio.chain"
"BTC.chain"
"Facebook.chain"
"Song.chain"
"ant.chain"
"b.chain"
"d.chain"
"help.chain"
"k.chain"
"l.chain"
"m.chain"
"meet.chain"
"o.chain"
"s.chain"
"y.chain"
```

### Pointers

This is basically a restricted reply from `name/:id` endpoint, returning just pointers.

```
$ curl -s "http://localhost:4000/name/pointers/wwwbeaconoidcom.chain" | jq '.'
{
  "account_pubkey": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
}
```

### Pointees

Returns names pointing to a particular pubkey, partitioned into `active` and `inactive` sets.

```
$ curl -s "http://localhost:4000/name/pointees/ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C" | jq '.'
{
  "active": {
    "account_pubkey": [
      {
        "active_from": 279555,
        "expire_height": 329558,
        "name": "wwwbeaconoidcom.chain",
        "update": {
          "block_height": 279558,
          "micro_index": 51,
          "tx_index": 12942695
        }
      }
    ]
  },
  "inactive": {}
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

## Tests

### Controller tests
The database has to be fully synced.
  * Run the tests with `make test`

### Performance test
This project has a performance test implemented. It's purpose is to test the availability and concurrency handling of the project. The performance test in this case would be spawning multiple clients, capable of making simultanious requests to the server at almost the same time.

**In order to run performance test:** The project should be up and running, then open a new shell and go to the project's root folder and execute the next command:

```
mix bench 7
```
Where 7 - is a number of clients, performing various requests to the server. At the end of the test, the output of detailed information is printed in a console.

The example output would look like:
```
          Path: "/txi/87450"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 288.721 ms
          Min exec time: 19.315 ms
          Max exec time: 140.515 ms
          Average: 41.24585714285714 ms
          Mean: 79.91499999999999 ms
          Percentiles:
            50th: 25.95 ms
            80th: 31.266600000000004 ms
            90th: 75.19540000000003 ms
            99th: 133.98303999999996 ms
          ......................................................................
          

          Path: "/txs/backward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 337.618 ms
          Min exec time: 20.464 ms
          Max exec time: 172.871 ms
          Average: 48.231142857142856 ms
          Mean: 96.6675 ms
          Percentiles:
            50th: 27.833 ms
            80th: 34.619800000000005 ms
            90th: 90.18680000000005 ms
            99th: 164.60257999999993 ms
          ......................................................................
          

          Path: "/txs/count"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 197.263 ms
          Min exec time: 15.202 ms
          Max exec time: 34.976 ms
          Average: 28.18042857142857 ms
          Mean: 25.089 ms
          Percentiles:
            50th: 31.489 ms
            80th: 32.842 ms
            90th: 33.7028 ms
            99th: 34.84868 ms
          ......................................................................
          

          Path: "/txs/count/ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 279.705 ms
          Min exec time: 15.544 ms
          Max exec time: 140.428 ms
          Average: 39.957857142857144 ms
          Mean: 77.986 ms
          Percentiles:
            50th: 25.106 ms
            80th: 28.861800000000002 ms
            90th: 73.69660000000003 ms
            99th: 133.75485999999992 ms
          ......................................................................
          

          Path: "/txs/forward?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 406.254 ms
          Min exec time: 17.89 ms
          Max exec time: 125.932 ms
          Average: 58.03628571428572 ms
          Mean: 71.911 ms
          Percentiles:
            50th: 36.636 ms
            80th: 108.07120000000008 ms
            90th: 125.8612 ms
            99th: 125.92492 ms
          ......................................................................
          

          Path: "/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&type_group=name"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 180.596 ms
          Min exec time: 19.95 ms
          Max exec time: 29.385 ms
          Average: 25.79942857142857 ms
          Mean: 24.6675 ms
          Percentiles:
            50th: 27.927 ms
            80th: 28.7048 ms
            90th: 29.037 ms
            99th: 29.3502 ms
          ......................................................................
          

          Path: "/txs/forward?contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 302.195 ms
          Min exec time: 27.1 ms
          Max exec time: 97.08 ms
          Average: 43.17071428571428 ms
          Mean: 62.09 ms
          Percentiles:
            50th: 34.142 ms
            80th: 43.056 ms
            90th: 65.15940000000002 ms
            99th: 93.88793999999997 ms
          ......................................................................
          

          Path: "/txs/forward?name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&limit=1"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 305.898 ms
          Min exec time: 19.572 ms
          Max exec time: 144.61 ms
          Average: 43.699714285714286 ms
          Mean: 82.09100000000001 ms
          Percentiles:
            50th: 27.913 ms
            80th: 32.4152 ms
            90th: 77.34940000000003 ms
            99th: 137.88393999999994 ms
          ......................................................................
          

          Path: "/txs/forward?oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&limit=1"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 280.388 ms
          Min exec time: 13.594 ms
          Max exec time: 140.548 ms
          Average: 40.05542857142857 ms
          Mean: 77.071 ms
          Percentiles:
            50th: 24.055 ms
            80th: 31.335600000000007 ms
            90th: 75.71200000000003 ms
            99th: 134.06439999999998 ms
          ......................................................................
          

          Path: "/txs/forward?type=channel_create&limit=1"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 169.413 ms
          Min exec time: 19.445 ms
          Max exec time: 30.124 ms
          Average: 24.201857142857143 ms
          Mean: 24.7845 ms
          Percentiles:
            50th: 23.397 ms
            80th: 27.985800000000005 ms
            90th: 29.1262 ms
            99th: 30.024219999999996 ms
          ......................................................................
          

          Path: "/txs/forward?type_group=oracle&limit=1"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 179.82 ms
          Min exec time: 17.984 ms
          Max exec time: 39.395 ms
          Average: 25.68857142857143 ms
          Mean: 28.689500000000002 ms
          Percentiles:
            50th: 23.537 ms
            80th: 32.02700000000001 ms
            90th: 35.83760000000001 ms
            99th: 39.03925999999999 ms
          ......................................................................
          

          Path: "/txs/gen/223000-223007?limit=30"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 538.766 ms
          Min exec time: 45.564 ms
          Max exec time: 166.333 ms
          Average: 76.96657142857143 ms
          Mean: 105.9485 ms
          Percentiles:
            50th: 48.047 ms
            80th: 96.5982 ms
            90th: 126.21220000000002 ms
            99th: 162.32091999999997 ms
          ......................................................................
          

          Path: "/txs/txi/409222-501000?limit=30"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 481.281 ms
          Min exec time: 43.973 ms
          Max exec time: 169.334 ms
          Average: 68.75442857142858 ms
          Mean: 106.65350000000001 ms
          Percentiles:
            50th: 53.573 ms
            80th: 59.836 ms
            90th: 104.26400000000002 ms
            99th: 162.82699999999994 ms
          ......................................................................
          

          Path: "/txs/txi/509111"
          Number of requests: 7
          Successful requests: 7
          Failed requests: 0
          Total execution time: 389.054 ms
          Min exec time: 16.093 ms
          Max exec time: 140.467 ms
          Average: 55.579142857142855 ms
          Mean: 78.28 ms
          Percentiles:
            50th: 24.174 ms
            80th: 117.27580000000007 ms
            90th: 140.4424 ms
            99th: 140.46454 ms
          ......................................................................
```
