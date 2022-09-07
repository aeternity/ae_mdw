# AeMdw - Aeternity Middleware

<!-- use emacs or npm markdown-toc with "markdown-toc --bullets=- README.md" -->
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Start](#start)
  - [Start middleware](#start-middleware)
  - [Build and start with Docker](#build-and-start-with-docker)
  - [Docker Configuration](#docker-configuration)
  - [Docker setup for local dev](#docker-setup-for-local-dev-1)
- [Hosted infrastructure](#hosted-infrastructure)
- [HTTP v2 (latest) endpoints](#http-v2-latest-endpoints)
- [HTTP v1 (deprecated) endpoints](#http-v1-endpoints-deprecated)
- [Pagination](#pagination)
- [Additional endpoint options](#additional-endpoint-options)
- [Transactions](#transactions)
- [Blocks](#blocks)
- [Naming System](#naming-system)
- [Contracts](#contracts)
- [Internal transfers](#internal-transfers)
- [Oracles](#oracles)
- [AEX9 tokens](#aex9-tokens)
- [AEX9 contract balances](#aex9-contract-balances)
- [Statistics](#statistics)
- [Migrating to v2](#migrating-to-v2)
- [Websocket interface](#websocket-interface)
- [Tests](#tests)

<!-- markdown-toc end -->


## Overview

The middleware is a caching and reporting layer which sits in front of the nodes of the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

The architecture of the app is explained [here](docs/architecture.md).

## Prerequisites

Ensure that you have [Elixir](https://elixir-lang.org/install.html) installed, using Erlang 22 or newer.

## Setup

`git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`
  * This project depends on [æternity](https://github.com/aeternity/aeternity) node. It should be then compiled and the path to the node should be configured in `config.exs`, or you can simply export `NODEROOT`. If the variable is not set, by default the path is `../aeternity/_build/local/`.

```
export NODEROOT="path/to/your/node"
```
The NODEROOT directory should contain directories: `bin`, `lib`, `plugins`, `rel` of AE node installation.

### Docker setup for local dev

Alternatively, you can set up a local docker instance the develop for local development. Simply clone the repo and start a new docker instance:

```
git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`
make docker-shell
```

You should now be able to navigate through the project located in the `/app` directory.

## Start

### Start middleware

  * Install dependencies with `make compile-backend`
  * Start middleware with `make shell` (if using alternative node directory specify NODEROOT)

The project will compile only backend-related files and start the middleware.

### Build and start with Docker

As the project comes with `Dockerfile` and `docker-compose.yml`, it is possible to build and run it by using Docker:

  * To build docker image, execute in root folder of the project: `docker-compose build`
  * Then, start middleware container `docker-compose up`

### Docker Configuration

By default, the `aeternity.yaml` config file which is used for `aeternity` node, is located under `docker/` folder. However, it is also possible to use your own defined `aeternity.yaml` file, by simply replacing the existing one. This file will be copied into container and will be used as a node configuration file. More information regarding configration could be found [here](https://docs.aeternity.io/en/stable/configuration/)

**NOTE:** Currently, only `ae_uat` and `ae_mainnet` network ids are supported!

It is also possible that middleware will produce blockchain database (if `aeternity.yaml` is configured to persist the blockchain database), which is located under `mnesia/` folder. This folder could also be replaced with existing database snapshot.

**NOTE:** `db_path` option under `chain` configuration, **should not** be configured and must be left by default.

### Docker setup for local dev

When inside the docker dev instance (`make docker-shell`), some useful commands
that you might want to run are:

```
iex --sname aeternity@localhost -S mix                                        # IEx shell
elixir --sname aeternity@localhost -S mix test                                # Unit tests
INTEGRATION_TEST=1 elixir --sname aeternity@localhost -S mix test.integration # Integration tests
elixir --sname aeternity@localhost -S mix phx.server                          # Start the server
mix format                                                                    # Run formatting tool
mix credo                                                                     # Run `credo` tool
mix dialyzer                                                                  # Run `dialyzer` tool
```

## Hosted Infrastructure

We currently provide hosted infrastructure at https://mainnet.aeternity.io/mdw/ , all examples here are based on it.

**NOTE:** Local deploy with default configuration endpoints **will not** contain `/mdw/` segment on the path.

## HTTP v2 (latest) endpoints

```
GET /v2/blocks                         - returns generation blocks
GET /v2/blocks/:hash                   - returns block by hash
GET /v2/blocks/:kbi                    - returns key block by integer index
GET /v2/blocks/:kbi/:mbi               - returns micro block by integer indices

GET /v2/txs                            - returns transactions in any direction
GET /v2/txs/:hash_or_index             - returns transaction by hash or index
GET /v2/txs/count                      - returns total number of transactions (last transaction index + 1)
GET /v2/txs/count/:id                  - returns counts of transactions per transaction field for given id

GET /v2/contracts/logs                    - returns contract logs
GET /v2/contracts/call                    - returns contract calls

GET /v2/names                              - returns names
GET /v2/names/search                       - returns names and auctions filtered by a query
GET /v2/names/:id/auction                  - returns name auction
GET /v2/names/:id/pointers                 - returns name pointer
GET /v2/names/:id/pointees                 - returns name pointees
GET /v2/names/auctions                     - returns all name auctions
GET /v2/names/:id                          - returns name

GET /v2/oracles                         - returns expired oracles ordered by expiration height, filtered by active/inactive state and scope
GET /v2/oracles/:id                     - returns oracle information by hash

GET /v2/channels                        - returns active channels ordered by activation height

GET /v2/transfers                        - returns internal transfers from the top of the chain

GET /v2/aex9                                           - returns aex9 contracts
GET /v2/aex141                                         - returns aex141 contracts
GET /v2/aex9/:contract_id                              - returns aex9 contract tokens
GET /v2/aex141/:contract_id                            - returns aex141 contract tokens
GET /v2/aex9/:contract_id/balances                     - returns aex9 contract balances
GET /v2/aex9/:contract_id/balances/:account_id         - returns aex9 contract account balance
GET /v2/aex9/account-balances/:account_id              - returns aex9 account balances
GET /v2/aex9/transfers/from/:sender                    - returns aex9 transfers from sender
GET /v2/aex9/transfers/to/:recipient                   - returns aex9 transfers to recipient
GET /v2/aex9/transfers/from-to/:sender/:recipient      - returns aex9 transfers from sender to recipient
GET /v2/aex9/:contract_id/balances/:account_id/history - returns aex9 contract account balanances history

GET /v2/deltastats                       - returns statistics for generations from tip of the chain
GET /v2/totalstats                       - returns aggregated statistics for generations from tip of the chain
GET /v2/minerstats                       - returns total rewards for each miner

GET /v2/status                           - returns middleware status
```

## HTTP v1 endpoints (DEPRECATED)

These endpoints are soon to be deprecated and should no longer be used.

```
GET  /name/:id                          - returns name information by hash or plain name
GET  /name/auction/:id                  - returns name information for auction, by hash or plain name
GET  /name/pointers/:id                 - returns pointers of a name specified by hash of plain name
GET  /name/pointees/:id                 - returns names which point to id specified by hash
GET  /names/owned_by/:id                - returns names owned by account and auctions with top bid from account
GET  /names/search/:prefix              - returns names matching the provided prefix

GET  /names/auctions                    - returns name auctions ordered by (optional) query parameters
GET  /names/auctions/:scope_type/:range - returns name auctions for continuation link
GET  /names/inactive                    - returns expired names ordered by (optional) query parameters
GET  /names/inactive/:scope_type/:range - returns expired names for continuation link
GET  /names/active                      - returns active names ordered by (optional) query parameters
GET  /names/active/:scope_type/:range   - returns active names for continuation link
GET  /names                             - returns all names (active and expired) ordered by (optional) query parameters
GET  /names/:scope_type/:range          - returns all names for continuation link

GET /aex9/by_name                       - returns AEX9 tokens, filtered by token name
GET /aex9/by_symbol                     - returns AEX9 tokens, filtered by token symbol

GET /aex9/balance/gen/:range/:contract_id/:account_id      - returns AEX9 token balance in range for given contract and account
GET /aex9/balance/hash/:blockhash/:contract_id/:account_id - returns AEX9 token balance at block for given contract and account
GET /aex9/balance/:contract_id/:account_id                 - returns current AEX9 token balance for given contract and account

GET /aex9/balances/gen/:height/account/:account_id         - returns AEX9 token balances of all contracts at height for given account
GET /aex9/balances/hash/:blockhash/account/:account_id     - returns AEX9 token balances of all contracts at blockhash for given account
GET /aex9/balances/account/:account_id                     - returns current AEX9 token balances of all contracts for given account

GET /aex9/balances/gen/:range/:contract_id       - returns all AEX9 token balances in range for given contract
GET /aex9/balances/hash/:blockhash/:contract_id  - returns all AEX9 token balances at block for given contract
GET /aex9/balances/:contract_id                  - returns all current AEX9 token balances for given contract

GET /aex9/transfers/from/:sender                 - returns all transfers of AEX9 tokens from sender
GET /aex9/transfers/to/:recipient                - returns all transfers of AEX9 tokens to recipient
GET /aex9/transfers/from-to/:sender/:recipient   - returns all transfers of AEX9 tokens between sender and recipient

GET /contracts/logs                      - returns contract logs
GET /contracts/logs/:direction           - returns contract logs from genesis or from the tip of chain
GET /contracts/logs/:scope_type/:range   - returns contract logs from in given range

GET /contracts/calls                     - returns function calls inside of the contracts
GET /contracts/calls/:direction          - returns function calls inside of the contracts from genesis or from the tip of chain
GET /contracts/calls/:scope_type/:range  - returns function calls inside of the contracts in a given range

GET /status                              - returns middleware status
```

## Pagination

The application does not support paginated page-based endpoints. Instead, a
cursor-based pagination is offered. This means that in order to traverse through
a list of pages for any of the pagianted endpoints, either the `next` or `prev`
field from the current page has to be used instead.

Asking for an arbitrary page, without first retrieving it from the `next` or
`prev` field **is not supported**.

The paginated endpoints return JSON in the follwing format:

```
{
  "data": [...objects...],
  "next": continuation-URL or null,
  "prev": continuation-URL or null
}
````

The `continuation-URL`, when concatenated with host, **has to be used** to
retrieve a new page of results.

Examples

Getting the first transaction:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1" | jq '.'
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
  "next": "/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779354&limit=1",
  "prev": "/txs/backward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=19813844&limit=1&rev=1"
}
```

Getting the next transaction by prepending host (https://mainnet.aeternity.io/mdw) to the continuation-URL from last request:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779354&limit=1" | jq '.'
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
  "next": "/txs/forward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779356&limit=1",
  "prev": "/txs/backward?account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1776073&limit=1&rev=1"
}
```

Once there are no more transactions for a query, the `next` key is set to `null`.

### Limit

The client can set `limit` explicitly if he wishes to receive different number
of transactions in the reply than `10` (max `100`).

### Scope

The `scope` paramter specifies the time period to look for transactions matching the criteria:

- `gen:A-B`   - from generation A to B (forward if A < B, backward otherwise)
- `txi:A-B`   - from transaction index A to B (forward if A < B, backward otherwise)

Not all paginated endpoints support all scopes.

### Direction

All paginated endpoints support a `direction` parameter that specifies the order in which results are expected to be returned.

It can be either `forward` or `backward` (default).

## Additional endpoint options

In many of the endpoints there's some additional query parameters that can be sent to change the endpoint behavior.

### `expand`

When `expand=true` is sent on the URL, it displays additional information.

Most oracle and name endpoints allow this option.

### `top`

When `top=true`, it displays the latest state of the changes by querying the node directly. This is allowed on some of the `AEx9` endpoints to obtain the latest balances state for a given contract.

### `tx_hash`

Currently, in the endpoints created from the beginning, transactions were identified by a "transaction index". Since recently, we've decided this shouldn't really be the case: transactions are to be identified exclusively via the transaction hash. This is because forks caused different transactions to have the same (consecutive and sequentially calculated) transaction indexes.

For the new endpoints, though, we **highly recommend not to use transaction indexes**, instead, use `tx_hash=true` for all endpoints and use exclusively the transaction hashes.

In the newer versions of the API, the transaction index will stop being exposed, regardless of the `tx_hash`query parameter.

----

## Transactions

### `/v2/txs`

Querying for transactions via `/v2/txs` endpoint supports 3 kinds of parameters specifying which transactions should be part of the reply:

- types
- generic ids
- transaction fields

#### Types

Types of transactions in the resulting set can be constrained by providing `type` and/or `type_group` parameter.
The query allows providing of multiple type & type_group parameters - they form a union of admissible types.
(In the other words - they are combined with `OR`.)

Supported types:

* `channel_close_mutual`, `channel_close_solo`, `channel_create`, `channel_deposit`, `channel_force_progress`, `channel_offchain`, `channel_settle`, `channel_slash`, `channel_snapshot_solo`, `channel_withdraw`.
* `contract_call`, `contract_create`
* `ga_attach`, `ga_meta`
* `name_claim`, `name_preclaim`, `name_revoke`, `name_transfer`, `name_update`
* `oracle_extend`, `oracle_query`, `oracle_register`, `oracle_response`
* `paying_for`
* `spend`

Supported type groups:

* channel
* contract
* ga
* name
* oracle
* paying
* spend

Examples:

`type` parameter:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&type=channel_create&limit=1" | jq '.'
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
  "next": "/txs/forward?cursor=73270&limit=1&type=channel_create"
}
```

`type_group` parameter:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&type_group=oracle&limit=1" | jq '.'
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
  "next": "/txs/forward?cursor=8892&limit=1&type_group=oracle"
}
```

#### Generic IDs

Generic ids allow selecting of transactions related to the provided id in `any` way.

With generic ids, it is possible to select also `create`/`register` transactions of particular AEternity object (like contract, channel or oracle), despite the fact that these transactions don't have the ID of the created object among its transaction fields.

Supported generic IDs:

- `account`
- `contract`
- `channel`
- `oracle`

(todo: name)

Examples

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2" | jq '.'
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
        "code": "cb_+QdxRgOgfRB0ofOTJwMaz73GwgUNX4rSsqh81yEyoDCgyFqUs63AuQdDuQXM/ir6YP4ENwEHNwAvGIgABwwE+wNBVElQX05PVF9FWElTVElORxoKBogrGggGABoKCoQoLAgIKwoMCiguDgAMKC4QAgwaChKKMQoUElUACwAUOA4CDAEAJwwIDwIcCwAUCi4QDAIODAIuJwwEKCwICC0KhIQtqoqKFBwaCkCGVQALACgsCAgrCEBE/DMGBgYCBgQDEWWl4A/+PR6JaAA3ADcHZ3cHZwc3AgcHZwd3Zwc3BkcAdwcHBwdnBzcERwAHBwdHAEcCDAKCDAKEDAKGDAKIDAKKDAKMDAKOJwwOAP5E1kQfADcCRwJHADcAGg6CLwAaDoQvABoOhi8AGg6ILwAaDoovABoGjAIaBo4AAQM//liqK7MANwF3JzcGRwB3BwcHBy8YggAHDAT7A0FVUkxfTk9UX0VYSVNUSU5HGgoGghoKCogyCAoMAxFkJuW0KxgGACcMBAQDEWh21t/+W1GPJgA3AXcHLxiCAAcMBPsDQVVSTF9OT1RfRVhJU1RJTkcaCgaCKxoIBgAaCgqEKyoMCggoLAIMAP5kJuW0AjcC9/f3KB4CAgIoLAgCIBAABwwEAQMDNDgCAwD+ZOFddAA3AUcCNwACAxFsZXWrDwJvgibPGgaOAAEDP/5lpeAPAjcBhwM3A0cAB3c3A0cAB3c3A0cAB3c3AAn9AAIEBkY2AAAARjYCAAJGNgQABGOuBJ8Bgbfh7SDBdTd1sh5gynCHKbCjz+owLcaWOKxkvaOqFD+8AAIBAz9GNgAAAEY2AgACRjYEAARjrgSfAYFroODuqDgz06d0bgFzLA3+WX8iEYX/NjmzrNC0Dn7DPgACAQM/RjYAAABGNgIAAkY2BAAEY64EnwGBV3MM/1lAjn9BBvAm1QmZfTQXiQoofqgl4BJQMzPBlBAAAgEDP/5nCp0GBDcCd0cANwAMAQIMAQALAAwCjgMA/BHCC+urNwJ3RwA3AAD+aHbW3wI3AjcCd/cn5wAn5wEzBAIHDAg2BAIMAQACAxFodtbfNQQCKBwCACgcAAACADkAAAEDA/5sZXWrAjcANwBVACAgjAcMBPsDOU9XTkVSX1JFUVVJUkVEAQM//pLx5vMANwJ3RwA3AxdHAAcMA38MAQIMAQAMAwAMAo4DAPwRJz2AQTcDd0cAFzcDF0cABwD+lMr4XwI3Avf39ygeAgICKCwGAiAQAAcMBAEDAzQ4AgMA/pWEerICNwF3BxoKAIIvGIIABwwIDAOvggABAD8PAgQIPgQEBhoKBoIxCggGLWqGhggALZqCggAIAQIIRjgEAAArGAAARPwjAAICAg8CBAg+BAQG/qSV6n0ANwFHADcAAgMRbGV1qw8Cb4Imz1MAZQEAAQM//rOIgD8ANwN3RwAXNwAMAQQMAQIMAQACAxHUfYQwDwJvgibPLxiCAAcMBvsDQVVSTF9OT1RfRVhJU1RJTkcaCgiCKxoKCAAaCgyEKyoODAooLhAADiguEgIOIzgSAAcMCvsDVU5PX1pFUk9fQU1PVU5UX1BBWU9VVGUJAhIMAQIMAhIMAQBE/DMGBgYEBgIDEWWl4A8PAm+CJs8UOBACDAMAJwwELSqEhAoBAz/+zeehTgA3AQcnNwRHAAcHBy8YiAAHDAT7A0FUSVBfTk9UX0VYSVNUSU5HGgoGijIIBgwDEZTK+F8MAQAnDAQEAxFodtbf/tR9hDACNwN3RwAXNwAMAQQMAQIMAQAMAwAMAo4DAPwRJz2AQTcDd0cAFzcDF0cABygMAAcMBvsDgU9SQUNMRV9TRVZJQ0VfQ0hFQ0tfQ0xBSU1fRkFJTEVEAQM//u3Sa0YENwJ3dzcADAEAAgMRlYR6sg8CABoKAoQs6gQCACsAACguBgAEKC4IAgQaCgqIMQoMClUADAECFDgGAlgADAIACwAnDAwPAhYLABQKKAgMAgYMAignDAQtKoSEAC2qiIgMFlUACwAMAQBE/DMGBgYABgQDEWWl4A+5AW4vExEq+mD+FXJldGlwET0eiWglZ2V0X3N0YXRlEUTWRB8RaW5pdBFYqiuzMXRpcHNfZm9yX3VybBFbUY8mRXVuY2xhaW1lZF9mb3JfdXJsEWQm5bQZLl4xMDU2EWThXXRVY2hhbmdlX29yYWNsZV9zZXJ2aWNlEWWl4A8tQ2hhaW4uZXZlbnQRZwqdBiVwcmVfY2xhaW0RaHbW31kuTGlzdEludGVybmFsLmZsYXRfbWFwEWxldatZLlRpcHBpbmcucmVxdWlyZV9vd25lchGS8ebzLWNoZWNrX2NsYWltEZTK+F8ZLl4xMDU1EZWEerJNLlRpcHBpbmcuZ2V0X3VybF9pZBGklep9PW1pZ3JhdGVfYmFsYW5jZRGziIA/FWNsYWltEc3noU45cmV0aXBzX2Zvcl90aXAR1H2EMJ0uVGlwcGluZy5yZXF1aXJlX2FsbG93ZWRfb3JhY2xlX3NlcnZpY2UR7dJrRg10aXCCLwCFNC4yLjAAQNBRMA==",
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
        "abi_version": 3,
        "amount": 1e+16,
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
        "call_data": "cb_KxHt0mtGK2lodHRwczovL2dpdGh1Yi5jb20vdGhlcGl3bzlDb29sIHByb2plY3RzIZ01af4=",
        "caller_id": "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2",
        "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "fee": 182980000000000,
        "function": "tip",
        "gas": 1579000,
        "gas_price": 1000000000,
        "gas_used": 3600,
        "log": [
          {
            "address": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
            "data": "cb_aHR0cHM6Ly9naXRodWIuY29tL3RoZXBpd2+QKOcm",
            "topics": [
              "83172428477288860679626635256348428097419935810558542860159024775388982427580",
              "32049452134983951870486158652299990269658301415986031571975774292043131948665",
              "10000000000000000"
            ]
          }
        ],
        "nonce": 80,
        "result": "ok",
        "return": {
          "type": "unit",
          "value": ""
        },
        "return_type": "ok",
        "type": "ContractCallTx",
        "version": 1
      },
      "tx_index": 8395071
    }
  ],
  "next": "/txs/forward?contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=8401663&limit=2"
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&limit=1" | jq '.'
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
  "next": "/txs/forward?cursor=600286&limit=1&oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&limit=2" | jq '.'
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
  "next": "/txs/forward?channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&cursor=94617&limit=2"
}
```

#### Transaction fields

Every transaction record has one or more fields with identifier, represented by public key.
Middleware is indexing these fields and allows them to be used in the query.

**Supported fields with provided transaction type:**

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
- contract_create - owner_id, contract_id
- ga_attach - owner_id, contract_id
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

**Supported freestanding fields:**

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

**Supported inner transactions fields:**

The ga_meta and paying_for transactions have inner transactions which might be filtered as if they were not inner.

For example, for a GAMetaTx with inner SpendTx, one might request with the following query params:
- spend.recipient_id or
- spend.sender_id or
- spend.recipient_id and spend.sender_id

Examples

with provided transaction type (`name_transfer`):
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&limit=1" | jq '.'
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
  "next": "/txs/forward?cursor=11734834&limit=1&name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF"
}
```

freestanding field `from_id`, and via `jq` extracting only tx_index and transaction type:
```
curl -s "https://mainnet.aeternity.io/mdw/v2/txs?from_id=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&limit=5" | jq '.data | .[] | [.tx_index, .tx.type]'
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

#### Mixing of query parameters

The query string can mix types, global ids and transaction fields.

The resulting set of transactions must meet all constraints specified by parameters denoting ID (global ids and transaction fields) - the parameters are combined with `AND`.

If `type` or `type_group` is provided, the transaction in the result set must be of some type specified by these parameters.

#### Examples

transactions where each transaction contains both accounts, no matter at which field:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1" | jq '.'
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
  "next": "/txs/backward?account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&cursor=17022424&limit=1",
  "prev": null
}
```

spend transactions between sender and recipient (transaction type = spend is deduced from the fields):
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&limit=1" | jq '.'
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
  "next": "/txs/forward?cursor=41&limit=1&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
  "prev": null
}
```

name related transactions for account:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&type_group=name" | jq '.'
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
  "next": null,
  "prev": null
}
```

### `/v2/txs/:hash_or_txi`

Single transactions can be obtained by either the identifying hash or transaction index.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq" | jq '.'
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

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/10000000" | jq '.'
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

### `/txs/count`

Counting all transactions

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/count" | jq '.'
11921825
```

It can also be scoped by generations:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/count?scope=gen:123-456" | jq '.'
23
```

Or by address:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/count?id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR" | jq '.'
19323
```

Or by type:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/count?type=oracle_register" | jq '.'
286
```

**NOTE**: It cannot be filtered by more than one of these filters.

### `/txs/count/:address`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/txs/count/ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR" | jq '.'
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

---

## Blocks

### `/v2/blocks` [DEPRECATED use /v2/key-blocks instead]

There are several endpoints for querying block(s) or generation(s). A generation can be understood as key block and micro blocks containing transactions.

Since we are returning whole generations, replies can be very large.

Examples below are trimmed heavily.

With /v2/blocks endpoint ("micro_blocks" as a sorted list):

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks?scope=gen:101125-101125" | jq '.'
{
  "data": [
    {
      "beneficiary": "ak_2MR38Zf355m6JtP13T3WEcUcSLVLCxjGvjk6zG95S2mfKohcSS",
      "hash": "kh_2MK98WvTtAMzvNNJSi62iConXWshwDM49pfyQi2uVPXE73vv7p",
      "height": 101125,
      "info": "cb_AAAAAfy4hFE=",
      "micro_blocks": [
        {
          "hash": "mh_3cSMUMFHxFzVV7kCSkbi6kcsUNBk6wU5BAfkFxxPRTFuyZsqG",
          "height": 101125,
          "pof_hash": "no_fraud",
          "prev_hash": "kh_2MK98WvTtAMzvNNJSi62iConXWshwDM49pfyQi2uVPXE73vv7p",
          "prev_key_hash": "kh_2MK98WvTtAMzvNNJSi62iConXWshwDM49pfyQi2uVPXE73vv7p",
          "signature": "sg_3NZ23RXhgg5NWebsfG6CHSBzpjgB9Nm8pgD9rVczsTcPiXN6tJziSLHGSZban3DLFsnyp3qU1GmnNZLYPG4cFmXvusJiq",
          "state_hash": "bs_2kR2LUjxrxNtibd4BFpnvgykJTwM9K8i7eYoYN1fJsmhTRUc2h",
          "time": 1561595880058,
          "transactions": {
            "th_28ixRZNWVJXdQ3C43HstKYAr7P1nSkMN1A2X5myE3pZz7Lao6M": {
              "block_hash": "mh_3cSMUMFHxFzVV7kCSkbi6kcsUNBk6wU5BAfkFxxPRTFuyZsqG",
              "block_height": 101125,
              "hash": "th_28ixRZNWVJXdQ3C43HstKYAr7P1nSkMN1A2X5myE3pZz7Lao6M",
              "signatures": [
                "sg_9mPr9vVGpqhTokKjzof6PLrEAPgBuR9xr6BbVPr8MxxG4GPwe7LCoBqoE7tWoxxWzkZdTUQHCHCkhL9nDBLxFkN9QLUED"
              ],
              "tx": {
                "amount": 32223629770000000000,
                "fee": 130000000000000,
                "nonce": 2547,
                "payload": "ba_Xfbg4g==",
                "recipient_id": "ak_2ASdNERRwAYmoNhxVuYC3k6RV5L2tbaK974QM5emcdzPNwSEUd",
                "sender_id": "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF",
                "ttl": 101424,
                "type": "SpendTx",
                "version": 1
              }
            },
            "th_2ioXeSv9Mbh7nMNtNtJFc8Nc6Nd9dFZBscZnC9YKmMw6FqLodG": {
              ...
            },
            "th_SUXzH48FMioCy3P4NwbwC2hZjc99rgRHZs8HJwcvnsNfwBSDX": {
              ...
            },
            "th_pMGxKY4hELiqu9Xm91DHpzYQZD8gkJrc12aa4hF8mYDMAve4t": {
              ...
            }
          },
          "txs_hash": "bx_AqKk4fiLGM13cQxgta4apaHPnzgWK4Epb4pnUVQMAic3ncFxs",
          "version": 3
        }
      ],
      "miner": "ak_2HToRDUsCuBqdGsFqCCE19chrRQ7hhYE5Ebd3LETfwnk3gGnzX",
      "nonce": 9256408633249850000,
      "pow": [
        5377241,
        6371180,
        ...
      ],
      "prev_hash": "kh_tPiapdedaKhT8egWrtLWsvACbEzTbpECdWg9P8dTtK8P8w48s",
      "prev_key_hash": "kh_tPiapdedaKhT8egWrtLWsvACbEzTbpECdWg9P8dTtK8P8w48s",
      "state_hash": "bs_2SF46f1xU4uxiKKVmeT9jqFWJenftFzXTVse9GGLwtit78zHQP",
      "target": 504458445,
      "time": 1561595666398,
      "version": 3
    }
  ],
  "next": null,
  "prev": null
}
```

Numeric range:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks?scope=gen:100000-100100&limit=3" | jq '.'
{
  "data": [
    {
      "beneficiary": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash": "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
      "height": 100000,
      "info": "cb_AAAAAfy4hFE=",
      "micro_blocks": {
        "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS": {
          "hash": "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS",
          "height": 100000,
          "pof_hash": "no_fraud",
          "prev_hash": "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
          "prev_key_hash": "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
          "signature": "sg_DM1gKHR8acCcXF8i2YPLjMVPrCeG8J4QQYcFeLrpZvy3wjJzQ1dQcgF3H9p5uLWSJ4QTTymgCm3rERD1Q3xVeHrvVqMBa",
          "state_hash": "bs_2breNSbLBYoUXyo7oCAeeEeR4WYxvDhCU6CpcyxStwyJ24JPhJ",
          "time": 1561390173025,
          "transactions": {
            "th_VAGQK8LmPQ5NvQ6kJZz7rhQdMJ5nTJZ9uHRbDKRWDGD4Ex5Gj": {
              "block_hash": "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS",
              "block_height": 100000,
              "hash": "th_VAGQK8LmPQ5NvQ6kJZz7rhQdMJ5nTJZ9uHRbDKRWDGD4Ex5Gj",
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
              }
            }
          },
          "txs_hash": "bx_MbpXZycNCDzTXSqb5fVq9Nh217x9P4PjrdpLb5doz8PtPoZsD",
          "version": 3
        }
      },
      "miner": "ak_2K5fAjna26t2U2V6v2LwNBUZpT9puriPdvxifDmGRoqG1a7R3Z",
      "nonce": 14620604494251231000,
      "pow": [8664748,...,485310990],
      "prev_hash": "mh_2EFE1CxvXM2dKtu4Jt4yLAbW8gS5MkpDtNmGKHP4bPXDvtubKJ",
      "prev_key_hash": "kh_B18SQZmResYV5yqxbFUizKPqrtrjky3LESGUvRECDp9N2kNmA",
      "state_hash": "bs_185cZMdvy6wJXjCZDwGnLJ4TCrU18yxGSVkbtQh4DyCm2yPaV",
      "target": 504047608,
      "time": 1561390154570,
      "version": 3
    },
    {
      "beneficiary": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash": "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
      "height": 100001,
      "info": "cb_AAAAAfy4hFE=",
      "micro_blocks": {
        "mh_2nCMBDBchfPdEozWwAYsFyq8iBLRKptLpzcTHomRKut3wVUkZJ": {
          "hash": "mh_2nCMBDBchfPdEozWwAYsFyq8iBLRKptLpzcTHomRKut3wVUkZJ",
          "height": 100001,
          "pof_hash": "no_fraud",
          "prev_hash": "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
          "prev_key_hash": "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
          "signature": "sg_QJtdAT57RX6rhe51mseBAxq9VVZ46e93q6jm334rQGyk1mZoR52ya9rsh7zzibntdzS9d72GH5XTorSi7ubt8BDhn8A9v",
          "state_hash": "bs_2BUKS5vTvBgwP8G4gCnaZeExztr4op6xmGv81jUezoS7qBfAya",
          "time": 1561390314442,
          "transactions": {
            "th_HRJe3r5bMYeDWysqJayzbVLr4gQEDXfXcDemeXCJo2HHnxk9U": {
              "block_hash": "mh_2nCMBDBchfPdEozWwAYsFyq8iBLRKptLpzcTHomRKut3wVUkZJ",
              "block_height": 100001,
              "hash": "th_HRJe3r5bMYeDWysqJayzbVLr4gQEDXfXcDemeXCJo2HHnxk9U",
              "signatures": [
                "sg_7BFTstKBgmdKiZdW6EctPCV1UM4LdMX7yhkoa6NCQoiGP5mren1VmTEVTtANQagQdEmfJgDE6MgDvCN5YAJcWhw7Dd9qy"
              ],
              "tx": {
                "amount": 4.999e+21,
                "fee": 28000000001760,
                "nonce": 2773,
                "payload": "ba_Xfbg4g==",
                "recipient_id": "ak_2CZpwotEioaKag2ci6ULVqutbwgupVUdrDSsaVroLWGNrTfHyR",
                "sender_id": "ak_6sssiKcg7AywyJkfSdHz52RbDUq5cZe4V4hcvghXnrPz4H4Qg",
                "ttl": 100010,
                "type": "SpendTx",
                "version": 1
              }
            }
          },
          "txs_hash": "bx_xYB1Cnj7B4yPGK97rXQADj53MSdYBBFjBraiZnjYNh2u3t7vn",
          "version": 3
        },
        "mh_NxwB3r43rT4ghZscfuXhHNKNouuVQmU1Lkrf4sgCTPYy3Szdr": {
          "hash": "mh_NxwB3r43rT4ghZscfuXhHNKNouuVQmU1Lkrf4sgCTPYy3Szdr",
          "height": 100001,
          "pof_hash": "no_fraud",
          "prev_hash": "mh_2nCMBDBchfPdEozWwAYsFyq8iBLRKptLpzcTHomRKut3wVUkZJ",
          "prev_key_hash": "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
          "signature": "sg_JpXtMbaCcx3dCSntGCL5hQpynvQ5zuhvWH8njeB3xiwZL4FAS9PvZHvYHFoZCh4ZRjWXS2RTwUS9q34GUyropGUmyqPaU",
          "state_hash": "bs_hEFr1wBFMCYa6spbZyaSr3SBiwypjyHGsDKfTRPaAspLKNYWj",
          "time": 1561390321251,
          "transactions": {
            "th_2H3tAA8kuyv3hetRHzMY8At4GTaDz7Ta2KhNKWgG2QNufn9MML": {
              "block_hash": "mh_NxwB3r43rT4ghZscfuXhHNKNouuVQmU1Lkrf4sgCTPYy3Szdr",
              "block_height": 100001,
              "hash": "th_2H3tAA8kuyv3hetRHzMY8At4GTaDz7Ta2KhNKWgG2QNufn9MML",
              "signatures": [
                "sg_F1db1TVZaUypoWZVxscXh9GE6QTNJZaaDqDe2gpqbD93jAyRiY2mufByaxnxtZJPC8feiYThcri4p9aie4WsAf4gB1Jod"
              ],
              "tx": {
                "amount": 4.2098e+20,
                "fee": 20000000000000,
                "nonce": 721,
                "payload": "ba_Xfbg4g==",
                "recipient_id": "ak_2drSE1t9wNjzLqTMUH3LMaGExnZ26E9Vss5WENC9YncnZEZZQW",
                "sender_id": "ak_2mggc8gkx9nhkciBtYbq39T6Jzd7WBms6jgYoLAAeRNgdy3Md6",
                "ttl": 100501,
                "type": "SpendTx",
                "version": 1
              }
            }
          },
          "txs_hash": "bx_gsiG1snHbhc9RaUYkdiXc4jUbsxyKWKqshnDKwSsEBQSEuxDf",
          "version": 3
        }
      },
      "miner": "ak_2AT33FPB7DSvd3XU2nKPh4sUbBjb6jHWtKh6CF2b1eK2y3daA3",
      "nonce": 8862664339569828000,
      "pow": [7438320,...,519071892],
      "prev_hash": "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS",
      "prev_key_hash": "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
      "state_hash": "bs_Wqv4So3wfCV2eyJMnjfiGsrb1D7nrUk2r6K9ufgnX22J5wVPA",
      "target": 504063592,
      "time": 1561390309740,
      "version": 3
    },
    {
      "beneficiary": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash": "kh_2BXy8tftXFVj859j4YpkTyf7Ld5AXrvPqUSbYwGoWZpKQ9VNVB",
      "height": 100002,
      "info": "cb_AAAAAfy4hFE=",
      "micro_blocks": {
        "mh_2DgnYpByRcMdavZUr29dzA6E4Exy6MPmDoGKwJAfbgGqgYkhXo": {
          "hash": "mh_2DgnYpByRcMdavZUr29dzA6E4Exy6MPmDoGKwJAfbgGqgYkhXo",
          "height": 100002,
          "pof_hash": "no_fraud",
          "prev_hash": "kh_2BXy8tftXFVj859j4YpkTyf7Ld5AXrvPqUSbYwGoWZpKQ9VNVB",
          "prev_key_hash": "kh_2BXy8tftXFVj859j4YpkTyf7Ld5AXrvPqUSbYwGoWZpKQ9VNVB",
          "signature": "sg_4AWRGirnV9FFfZdCQZD6xcY422Sfqo32hL18AKBDV6MqZ3PJm3u9FuQ874SQDXkrD4P4aftT4UvFoRXKybKcDYZ1YrTSe",
          "state_hash": "bs_2f1fKQXp6BW93EMvoo53QCUn4cJJN8EnJ38WHaSVjsNTfFnPs8",
          "time": 1561390368180,
          "transactions": {
            "th_2MNiHqkHKUioTcGpob8mEyyd8stx176gKQwHtHb5jknuf2wggm": {
              "block_hash": "mh_2DgnYpByRcMdavZUr29dzA6E4Exy6MPmDoGKwJAfbgGqgYkhXo",
              "block_height": 100002,
              "hash": "th_2MNiHqkHKUioTcGpob8mEyyd8stx176gKQwHtHb5jknuf2wggm",
              "signatures": [
                "sg_RJtTUzjwMgQxay4EksNdHzCxAXQRobdSLxJLD6QqpwFXPkycCZkmWR239G93Q9RAwbXMzEykogPDj4r6MDZyFEJ3WSny2"
              ],
              "tx": {
                "amount": 3.26e+20,
                "fee": 16880000000000,
                "nonce": 536,
                "payload": "ba_Xfbg4g==",
                "recipient_id": "ak_2UBcNqdXQb4PvZaTz6zd4dVbPuJf29Jvx9gNqvmSQcoQK11RZW",
                "sender_id": "ak_dnzaNnchT7f3YT3CtrQ7GUjqGT6VaHzPxpf2efHWPuEAWKcht",
                "type": "SpendTx",
                "version": 1
              }
            }
          },
          "txs_hash": "bx_29BoCEp5xcJweJD6Dme4hipvE5VhSE8MwGFFfXnM8en5d48izY",
          "version": 3
        }
      },
      "miner": "ak_2VJtWGt45q8w9Aj7gYJPz9kZG3EU45xi6YZ4wgXSb25MeYGdfM",
      "nonce": 5829762670850390000,
      "pow": [1917903,...,530252456],
      "prev_hash": "mh_NxwB3r43rT4ghZscfuXhHNKNouuVQmU1Lkrf4sgCTPYy3Szdr",
      "prev_key_hash": "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
      "state_hash": "bs_2E75ChNX5EZo42xek6K64i5MZfQNxDUo5M9DwAufFRqQRqx3Z5",
      "target": 504062474,
      "time": 1561390340812,
      "version": 3
    }
  ],
  "next": "/v2/blocks/100000-100100?cursor=100003&limit=3",
  "prev": null
}
```

### `/v2/blocks/:hash_or_kbi`

A single block can be obtained by either the identifying `hash` or key-block index.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks/kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6" | jq '.'
{
  "beneficiary": "ak_2MR38Zf355m6JtP13T3WEcUcSLVLCxjGvjk6zG95S2mfKohcSS",
  "hash": "kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6",
  "height": 123008,
  "info": "cb_AAAAAfy4hFE=",
  "miner": "ak_Fqnmm5hRAMaVPWk8wzpodMopZgWghMns4mM7kSV1jgT89p9AV",
  "nonce": 9223756548132686000,
  "pow": [12359907, ..., 533633643],                                     # pow removed for clarity
  "prev_hash": "kh_hwin2p8u87mqiK836FixGa1pL9eBkL1Ju37Yi6EUebCgAf8rm",
  "prev_key_hash": "kh_hwin2p8u87mqiK836FixGa1pL9eBkL1Ju37Yi6EUebCgAf8rm",
  "state_hash": "bs_9Dg6mTmiJLpbg9dzgjnNFVidQesvZYZG3dEviUCd4oE1hUcna",
  "target": 504082055,
  "time": 1565548832164,
  "version": 3
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks/mh_25TNGuEkVGckfrH3rVwHiUsm2GFB17mKFEF3hYHR3zQrVXCRrp" | jq '.'
{
  "hash": "mh_25TNGuEkVGckfrH3rVwHiUsm2GFB17mKFEF3hYHR3zQrVXCRrp",
  "height": 123003,
  "pof_hash": "no_fraud",
  "prev_hash": "mh_2ALC3nX5Hm9488yhPKn65egU6KWugMnAyhYiBq3eRVn9Bf2mD1",
  "prev_key_hash": "kh_mrRQL1wvGNvXtF1HcicnPRbcm6uHtvpz5VztyqVsoCvybiEgY",
  "signature": "sg_JA6we1Pz2Ask15dNnsNF3Ziof2NcdbSsLrrX5xQtsnraQm9ytX7X2DXzAFm2TYcPwGEddkxRTrkvKcSZm6eZPDBDWEi1T",
  "state_hash": "bs_5xhq7iqCZAdVZx76RjFHFv1CdBoRLPV5L2goD1QDjRwEWXK53",
  "time": 1565548441990,
  "txs_hash": "bx_kjjNsYXDHNTaGJgbHryMb3C9eJkKMfijtWtvDDxtGTkzVbnai",
  "version": 3
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks/1234" | jq '.'
{
  "beneficiary": "ak_2RGTeERHPm9zCo9EsaVAh8tDcsetFSVsD9VVi5Dk1n94wF3EKm",
  "hash": "kh_2L9i7dMqrYiUs6um71kwnZsNDqD9xBbD71EiVoWFtbMUKs2Tka",
  "height": 1234,
  "info": "cb_Xfbg4g==",
  "miner": "ak_2wfU7H1B5iPNm7Qh6Fe4uqL2Swhuy1P2Y6Mja6FrrA6Lqqgs4U",
  "nonce": 3506640638825476600,
  "pow": [13191216, ..., 527787452],                                     # pow removed for clarity
  "prev_hash": "kh_28dE5V2VhN47H3vFePVvugz5XhwxqYHemo74cLV8xW4vq4vg3i",
  "prev_key_hash": "kh_28dE5V2VhN47H3vFePVvugz5XhwxqYHemo74cLV8xW4vq4vg3i",
  "state_hash": "bs_2WAAvA4HPNWWFa4nxScsHp8f332rVpZZz4uGsZg5SYe5pYPTdX",
  "target": 520781974,
  "time": 1543589552624,
  "version": 1
}
```

### `/v2/blocks/:kbi/:mbi`

Micro block are identified by height and sequence id (order) withing the generation, starting from 0.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/blocks/300000/0" | jq '.'
{
  "hash": "mh_2Nyaoy9CCPa8WBfzGbWXy5rd6AahJpBFxyXM9MMpCrvCqpkFj",
  "height": 300000,
  "pof_hash": "no_fraud",
  "prev_hash": "kh_2kJKKRfu6BMwNzYoDc5sJBSS4X3S1vdmiZitWQ84KEqWnGLoDe",
  "prev_key_hash": "kh_2kJKKRfu6BMwNzYoDc5sJBSS4X3S1vdmiZitWQ84KEqWnGLoDe",
  "signature": "sg_Ks256s7x8K3UFeUi6qV9ufZv7q9NtDXiSYJmoCKYivZCqEpJhKnVt3SViLzWWo9Lr149J5iUeZrxNNtv6Svn7eLAk22V5",
  "state_hash": "bs_EydSYyRMLdUBdtgzCgbmT6CHgisv5UWN18oW9Urjn6V7JUAfe",
  "time": 1597568157025,
  "txs_hash": "bx_2pJG7zzAELatCHr8QjNtc3QFx6vdf4p9gvgMwPzSjXeL1DHDkK",
  "version": 4
}
```

### `/v2/key-blocks`

New endpoint that returns a paginated list of key-blocks together with the amount of micro blocks and transactions each key-block generation has.

This endpoint should be used in place of `/v2/blocks`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/key-blocks?limit=1" | jq '.'
{
  "data": [
    {
      "micro_blocks_count": 180,
      "transactions_count": 244,
      "beneficiary": "ak_wM8yFU8eSETXU7VSN48HMDmevGoCMiuveQZgkPuRn1nTiRqyv",
      "hash": "kh_2w8M2XGQaEhrf5AQwKyibgskKshCeFNsmGCxjHUDbUMm8BdzaV",
      "height": 652730,
      "info": "cb_AAACjBq0Xcc=",
      "miner": "ak_2fh4U3GaZGV2PFy7x7UDPNZN9F4gi1sryKCP4VtJawjJbQVsGR",
      "nonce": 28361498886552,
      "pow": [
        8004426,
        25304189,
        41033042,
        48739301,
        55650278,
        69208239,
        78837065
      ],
      "prev_hash": "mh_2f4TgYysCB6x1N9KtUNbQDUjcDJkq4hNrCkMcLxutBb6ydsfa1",
      "prev_key_hash": "kh_Bfip7MNDMJGEe1PqCsPggUkuSQCAQFKAmWAM42jezSmUB3Zfm",
      "state_hash": "bs_kyyX1ujxAJm6orwxPghVJK8ZqxKMXuVUp5hUfnpjaJWnRgx3T",
      "target": 520137938,
      "time": 1662549337009,
      "version": 5
    }
  ],
  "next": "/v2/key-blocks?cursor=652729&limit=1",
  "prev": null
}
```

---

## Naming System

There are several endpoints for querying of the Naming System.

Name objects in Aeternity blockchain have a lifecycle formed by several types of transactions.
Names can become claimed (directly or via name auction), updated the lifespan or pointers, transferred the ownership and revoked when not needed.

Information about the name returned from the name endpoints summarizes this lifecycle in vectors of transaction indices, under keys `claims`, `updates`, `transfers` and optional transaction index in `revoke`.

Transaction index is useful for retrieving detailed information about the transaction via `txi/:index` endpoint.

Using `txi/:index` endpoint is flexible, on-demand way to get detailed transaction information, but in some situations leads to multiple round trips to the server.

Due to this reason, all name endpoints except `name/pointers` and `name/pointees` support `expand` parameter (either set to `true` or without value), which will replace the transaction indices with the JSON body of the transaction detail.

### `/v2/names`

Names can be filtered by state, which can containe the following values:

- `inactive` - for listing `inactive` names (expired or revoked)
- `active` - for listing `active` names
- `auction` - for listing `auctions`

They support ordering via parameters `by` (with value `activation`, `deactivation` or `name`), and `direction` (with value `forward` or `backward`).

Using the `by=activation` requires `state=active` and includes only sucessfully claimed names (those in auction won't appear yet).

Using the `by=deactivation` means for inactive names that they are sorted by the height of deactivation, whether the name had expired or had been revoked.
For active names it means they are sorted by expiration height.

Without these parameters, the endpoints return results ordered as if `by=deactivation` and `direction=backward` were provided.

The parameter `limit` (by default = 10) is optional, and limits the number of elements in the response.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names?limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "hash": "nm_qock4y2xnYdyy779vayFfu7YUBTwy9bTfoJeH4pM5EpRyJU3A",
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
      "hash": "nm_8vYbsvsrBow6jpxPHUtMLKG6EfTKqqwfpu425aJuHKafSxyR6",
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
  "next": "/v2/names?by=deactivation&cursor=703645-jiangjiajia.chain&direction=backward&expand=false&limit=2",
  "prev": null
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names?state=inactive&by=deactivation&direction=forward&limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "hash": "nm_PstDX8VxoTutPJG8YrXkWEwAfBoC5ZmoW1j5RZSNNyXa5oJSB",
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
      "hash": "nm_J9wKEZ1Deo4UAnNo5s5VTRccVCLdZexZBQJgA6YHYy67xDpqy",
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
  "next": "/v2/names?state=inactive&cursor=16117-philippsdk1.test&direction=forward&expand=false&limit=2",
  "prev": null
}
```

Active names

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names?state=active&by=name&limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "hash": "nm_23NKMgfB5igtdWHkY5BPMg75PykVrBTBpPAsE6Y1mYV3kZ8Nbd",
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
      "hash": "nm_2q5bUSTcibKsuRfGnXSFC5JkUSUxiy9UbMuQ2uJn2xiYNZdcbL",
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
  "next": "/v2/names?state=active&cursor=zz.chain&direction=backward&expand=false&limit=2",
  "prev": null
}
```

Additionally, this endpoint allows you to filter by name owner using the query param `owned_by`:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names?owned_by=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN&by=name" | jq '.'
{
  "active": [
    {
      "active": true,
      "auction": null,
      "hash": "nm_ekASCb5VvGYg8tcdA93A4dsMRNCsBVrv8b5kozYNjr2ofBbga",
      "info": {
        "active_from": 440894,
        "auction_timeout": 0,
        "claims": [
          23101974
        ],
        "expire_height": 630903,
        "ownership": {
          "current": "ak_VxVK5wdL2MbRZBFi8DHfTcnz19BMKAR51iTeqY8nNRJ3b3RSq",
          "original": "ak_VxVK5wdL2MbRZBFi8DHfTcnz19BMKAR51iTeqY8nNRJ3b3RSq"
        },
        "pointers": {
          "account_pubkey": "ak_VxVK5wdL2MbRZBFi8DHfTcnz19BMKAR51iTeqY8nNRJ3b3RSq"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          23579316
        ]
      },
      "name": "zzzzzzzzzzzzz.chain",
      "previous": [],
      "status": "name"
    },
    ...
    ],
  "top_bid": [
    {
      "active": false,
      "hash": "nm_2s2gjxQFYzcShL9gva2jWvzZ7mHPe4m6X6pqbyuSipZKCg1DLV",
      "info": {
        "auction_end": 316672,
        "bids": [
          14747888
        ],
        "last_bid": {
          "block_hash": "mh_gGVCDKzwBP85BGTiionuZrpibThyPUdqn8VWWVzvAVYN2YuGS",
          "block_height": 301792,
          "hash": "th_eWrp3M6REtTmVjGJqEvqXM5ejQ73irAptTtcaqTWNsBYJoxZ5",
          "micro_index": 0,
          "micro_time": 1597894719687,
          "signatures": [
            "sg_E3dyEYE9mrBXbFRN3PjCakpAN1VZbZAuYq8JKVq6ki8vvwsCaDMd947QHBx5pkcwFX1Y1AqiwhcYx5AUpQD1xYoXYHi63"
          ],
          "tx": {
            "account_id": "ak_2AVeRypSdS4ZosdKWW1C4avWU4eeC2Yq7oP7guBGy8jkxdYVUy",
            "fee": 16560000000000,
            "name": "nikita.chain",
            "name_fee": 51422900000000000000,
            "name_id": "nm_2s2gjxQFYzcShL9gva2jWvzZ7mHPe4m6X6pqbyuSipZKCg1DLV",
            "name_salt": 7461157538025441,
            "nonce": 43,
            "type": "NameClaimTx",
            "version": 2
          },
          "tx_index": 14747888
        }
      },
      "name": "nikita.chain",
      "previous": [],
      "status": "auction"
    }
  ]
}
```

An example of `by` usage:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names?state=active&by=activation&direction=forward&limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "auction": null,
      "hash": "nm_2FvtAFr3gPAQtNutEnjcPDQSqbhxDHBg9j8LE5WESPCJjzFmuU",
      "info": {
        "active_from": 161313,
        "auction_timeout": 0,
        "claims": [
          4681666
        ],
        "expire_height": 653635,
        "ownership": {
          "current": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV",
          "original": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV"
        },
        "pointers": {
          "account_pubkey": "ak_2QGAAqDXK7g8zCbck7zm25TGAW1hRuVCET2SRCCFCMSMjrVCrF"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          24868257,
          22196443,
          19655223,
          17065630,
          13654097,
          9992832,
          9992371,
          6685502
        ]
      },
      "name": "batchpayments.chain",
      "previous": [],
      "status": "name"
    },
    {
      "active": true,
      "auction": null,
      "hash": "nm_E5JeB8xLS9UR5qN65kDuAhRCHDno5B9pLwoXCm5DEKVpmWrUN",
      "info": {
        "active_from": 161349,
        "auction_timeout": 0,
        "claims": [
          4684245
        ],
        "expire_height": 653635,
        "ownership": {
          "current": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV",
          "original": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV"
        },
        "pointers": {
          "account_pubkey": "ak_2QGAAqDXK7g8zCbck7zm25TGAW1hRuVCET2SRCCFCMSMjrVCrF"
        },
        "revoke": null,
        "transfers": [],
        "updates": [
          24868289,
          22196724,
          19655216,
          17065615,
          13654148,
          9992939,
          6685785
        ]
      },
      "name": "internetofmoney.chain",
      "previous": [],
      "status": "name"
    }
  ],
  "next": "/v2/names?by=activation&cursor=161350-internetofvalue.chain&direction=forward&limit=2&state=active",
  "prev": null
}
```

### `/v2/names/search`

Prefix searching of names is possible via `/v2/names/search` endpoint.
By default, the prefix search will find names in any of the lifecycle states - `auction`, `active`, `inactive`.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/search?prefix=xxxxxx" | jq '.'
[
  [
    {
      "payload": {
        "active": true,
        "auction": null,
        "hash": "nm_n6mE2D37D5vEbLVSwvLr7haCbKt1Rtk8vczCywMRXFss3cPLs",
        "info": {
          "active_from": 513559,
          "auction_timeout": 0,
          "claims": [
            27875299
          ],
          "expire_height": 693559,
          "ownership": {
            "current": "ak_2fxRQ2STRnBdhu7XR1Q7amotX7FSaC1z73bwAuJX7nf8JDQ4PS",
            "original": "ak_2fxRQ2STRnBdhu7XR1Q7amotX7FSaC1z73bwAuJX7nf8JDQ4PS"
          },
          "pointers": {},
          "revoke": null,
          "transfers": [],
          "updates": []
        },
        "name": "xxxxxxxxxxxxx.chain",
        "previous": [],
        "status": "name"
      },
      "type": "name"
    },
  ...
]
```

Via the `only` parameter, it's possible to search for a name in particular lifecycle state only.
The parameter can be repeated:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/search?prefix=aaa&only=auction&only=inactive" | jq '.'
[
  {
    "active": false,
    "info": {
      "auction_end": 433568,
      "bids": [
        20309433
      ],
      "last_bid": {
        "block_hash": "mh_2j6HpTVpgqVoYLRVSiG7Rm2W6XfkCgMPMYTvtVDoykgAkrDPj3",
        "block_height": 403808,
        "hash": "th_swc2vXht9xjrVWXXHSMLaUqDFx21qLdHbwixgSagX8DNhwnVC",
        "micro_index": 0,
        "micro_time": 1616501035488,
        "signatures": [
          "sg_4RmWff8UECeL5h319TY7RVx7biDU7C36GfzhsbLDvy5DrJ3iRGDx6rk4FiwjgTZrH4hrSz4sJ4hr9AHFJHNGCq32PSkA1"
        ],
        "tx": {
          "account_id": "ak_2VKyfAmVpUjX69TKLBMRqdBgK4YXyrTi8J9L82RgvqaCycHYeq",
          "fee": 33040000000000,
          "name": "aaa.chain",
          "name_fee": 217830900000000000000,
          "name_id": "nm_246C5HgNYowJwj5p7mFrCrLs999ySoDa334r3SCqj9zRFbonBm",
          "name_salt": 2674742195530689,
          "nonce": 140,
          "type": "NameClaimTx",
          "version": 2
        },
        "tx_index": 20309433
      }
    },
    "name": "aaa.chain",
    "previous": [],
    "status": "auction"
  },
  {
    "active": false,
    "auction": null,
    "info": {
      "active_from": 18546,
      "auction_timeout": 0,
      "claims": [
        164943
      ],
      "expire_height": 135776,
      "ownership": {
        "current": "ak_24tr4igMX67zmJggQ1yUAJDQmofz8MFEU3hqc8EVAx1Un652e8",
        "original": "ak_24tr4igMX67zmJggQ1yUAJDQmofz8MFEU3hqc8EVAx1Un652e8"
      },
      "pointers": {
        "account_pubkey": "ak_24tr4igMX67zmJggQ1yUAJDQmofz8MFEU3hqc8EVAx1Un652e8"
      },
      "revoke": null,
      "transfers": [],
      "updates": [
        2114471,
        1224905,
        650357,
        650355,
        650354,
        307848
      ]
    },
    "name": "aaa.test",
    "previous": [],
    "status": "name"
  },
  ...
]
```

This endpoint also accepts the `expand` parameter:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/search?prefix=asdf&expand" | jq '.'
[
  {
    "active": false,
    "auction": null,
    "info": {
      "active_from": 80657,
      "auction_timeout": 0,
      "claims": [
        {
          "block_hash": "mh_2b6pVcaQGkkz8GmttTyzWdM2HpdBgAkY8hSoDQzsJy5sAAcVFX",
          "block_height": 80657,
          "hash": "th_q23GahzkBMFmATHi1BrGcPkP1kYVwCs9jE67nectQN6MPddGU",
          "micro_index": 0,
          "micro_time": 1557897366141,
          "signatures": [
            "sg_3s1kNCWYHRabHwpaYT7UKWgNmkDBJQbf6raK8Nz9KPxQDLfz94N3eUXZw6rL33yPVaf4hAuzFgqWEpbSqAkEiRcwmoLZN"
          ],
          "tx": {
            "account_id": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
            "fee": 20000000000000,
            "name": "asdf.test",
            "name_id": "nm_o5JPJRbmDV6EUaauPaP7z1fZvvroauvuF63pmg6NBqxHBGrE7",
            "name_salt": 123,
            "nonce": 24965,
            "ttl": 80756,
            "type": "NameClaimTx",
            "version": 2
          },
          "tx_index": 1789259
        }
      ],
      "expire_height": 131372,
      "ownership": {
        "current": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
        "original": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf"
      },
      "pointers": {
        "account_pubkey": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf"
      },
      "revoke": null,
      "transfers": [],
      "updates": [
        {
          "block_hash": "mh_2oLyC8yeBGvgJgCzaXRzqSsHRszEXsjrVwBFeLC4FGedEdEPpD",
          "block_height": 81372,
          "hash": "th_2fREBJgCYVo8nAAzEQAUUq5Qn7nHvrS6baRwUFeHaNDwaS6S83",
          "micro_index": 2,
          "micro_time": 1558026126012,
          "signatures": [
            "sg_GBc1ZsENYyrBvEi4APVoZFM99Y12Jx7bqKh7pKsdfanqEB7G4iarJedaKGjeWXyiVkfFju1WQkYykwkKkC8jBwRQ2jpRK"
          ],
          "tx": {
            "account_id": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
            "client_ttl": 50000,
            "fee": 30000000000000,
            "name": "asdf.test",
            "name_id": "nm_o5JPJRbmDV6EUaauPaP7z1fZvvroauvuF63pmg6NBqxHBGrE7",
            "name_ttl": 50000,
            "nonce": 40517,
            "pointers": [
              {
                "id": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
                "key": "account_pubkey"
              }
            ],
            "type": "NameUpdateTx",
            "version": 1
          },
          "tx_index": 1822284
        },
        {
          "block_hash": "mh_GFJ7tS12D4fKksfz7kQJJwXYs8eK4s2wAD1MA79XCXakuuAVq",
          "block_height": 81370,
          "hash": "th_2vZBGDF92GGxy93T11qCsXhrgm51k9mf5mkQ3GuoHVrYzbfPtB",
          "micro_index": 1,
          "micro_time": 1558025965641,
          "signatures": [
            "sg_Ai54pfkEptae3zrhy5UYD3tDSciHMyCfQSX9HWAHiF4g5M6W5dKHXxXDF2oZaAqeNPhtwH3ZfACwZPmHzCKHvB7C6sKCe"
          ],
          "tx": {
            "account_id": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
            "client_ttl": 50000,
            "fee": 30000000000000,
            "name": "asdf.test",
            "name_id": "nm_o5JPJRbmDV6EUaauPaP7z1fZvvroauvuF63pmg6NBqxHBGrE7",
            "name_ttl": 50000,
            "nonce": 40510,
            "pointers": [
              {
                "id": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
                "key": "account_pubkey"
              }
            ],
            "type": "NameUpdateTx",
            "version": 1
          },
          "tx_index": 1822277
        }
      ]
    },
...
]
```

### `/v2/names/auctions`

Without ordering parameters, the first auction in reply set expires the latest.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/auctions?limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "hash": "nm_2gck1wvusmLUH1pRJ6dUgHxuVBM5Nf75q64wZHB2TwadpHH6Xv",
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
      "hash": "nm_2G8VVfnRqJjxcpNu8vbHJyaYhCoR9Gys42AvaEK3hMN8tfXCr6",
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
  "next": "/v2/names?state=auctions&cursor=548763-svs.chain&direction=backward&expand=false&limit=2",
  "prev": null
}
```

To show auctions starting with the one expiring the earliest:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/auctions?by=expiration&direction=forward&limit=2" | jq '.data [] .info.auction_end'
300490
300636
```

Or, ordered by name, from the begining:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/auctions?by=name&direction=forward&limit=100" | jq '.data [] .name'
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

### `/v2/names/:name_or_hash`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/bear.test" | jq '.'
{
  "active": false,
  "hash": "nm_2aGpF2uJp1wDpuHoNDhhSztpoQr43dAjzZ5SyvfD2RSKTVmL6X",
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
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj" | jq '.'
{
  "active": true,
  "hash": "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj",
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
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/aeternity" | jq '.'
{
  "active": true,
  "hash": "nm_S4ofw6861biSJrXgHuJPo7VotLbrY8P9ngTLvgrRwbDEA3svc",
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
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/help" | jq '.'
{
  "active": false,
  "hash": "nm_2WoR2PCFXeLiLQH8C7GVbGpU57qDBqkQbPvaML8w3ijMQiei7E",
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

With `expand` parameter, notice how `claims` and `updates` have the transaction detail inlined:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/cryptobase.chain?expand" | jq '.'
{
  "active": true,
  "hash": "nm_2vAFLnmRbsQTNeZi9PzFgVWY6Un9rszFDaE3ubYqk1oJURxJ97",
  "info": {
    "active_from": 264318,
    "auction_timeout": null,
    "claims": [
      {
        "block_hash": "mh_gtErJSZWePyPyr8yoeQb3mUqA7YsjL6Ac7YKKMGqbbyNGcjWk",
        "block_height": 263838,
        "hash": "th_2aHZ1hCkuGRdB9f9F1g6brjwvxfzZ6c1rV8TAiGxRLncpdLJRA",
        "micro_index": 0,
        "micro_time": 1591023065609,
        "signatures": [
          "sg_BDED9YVuq7X7j51ni2jmfbj7tZ4Tx8KcTP3sx3W9C3aZwDLsXYEnNc9yCBbeGC1AcCkVBsGigSFPqNS5CXPCDXramjUNd"
        ],
        "tx": {
          "account_id": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr",
          "fee": 16620000000000,
          "name": "cryptobase.chain",
          "name_fee": 7502500000000000000,
          "name_id": "nm_2vAFLnmRbsQTNeZi9PzFgVWY6Un9rszFDaE3ubYqk1oJURxJ97",
          "name_salt": 7573518016165599,
          "nonce": 49,
          "type": "NameClaimTx",
          "version": 2
        },
        "tx_index": 11807560
      }
    ],
    "expire_height": 361829,
    "ownership": {
      "current": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr",
      "original": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr"
    },
    "pointers": {
      "account_pubkey": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr"
    },
    "revoke": null,
    "transfers": [],
    "updates": [
      {
        "block_hash": "mh_pFixjYGYcqtSMzHprsTB9t1Z3zp11W9yFgJJ7GoRfpBBpFyxS",
        "block_height": 311829,
        "hash": "th_W4L8X2FcWSi2cyGCayimNSWojEzyVjXSXk8EEJES2evTqxLzS",
        "micro_index": 16,
        "micro_time": 1599712936956,
        "signatures": [
          "sg_6PSRErVuLWGZAcRAW2fYDDNSsBPgccgxMjQciGCwqAeCKF16ykBVPghZWe2QPPTs86QTevoAPphtbhMCmZWpQSjrPR24L"
        ],
        "tx": {
          "account_id": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr",
          "client_ttl": 10500,
          "fee": 17840000000000,
          "name": "cryptobase.chain",
          "name_id": "nm_2vAFLnmRbsQTNeZi9PzFgVWY6Un9rszFDaE3ubYqk1oJURxJ97",
          "name_ttl": 50000,
          "nonce": 64,
          "pointers": [
            {
              "id": "ak_2J1B4qgybwgFVgfHSmPDWpdPogY4TxGnyoyNRL1oNZmhWyyzvr",
              "key": "account_pubkey"
            }
          ],
          "ttl": 312329,
          "type": "NameUpdateTx",
          "version": 1
        },
        "tx_index": 15494052
      }
    ]
  },
  "name": "cryptobase.chain",
  "previous": [],
  "status": "name"
}
```

### `/v2/names/:name/auction`

Auction specific name resolution is available behind this endpoint:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/nikita.chain/auction" | jq '.'
{
  "active": false,
  "hash": "nm_2s2gjxQFYzcShL9gva2jWvzZ7mHPe4m6X6pqbyuSipZKCg1DLV",
  "info": {
    "auction_end": 316672,
    "bids": [
      14747888
    ],
    "last_bid": {
      "block_hash": "mh_gGVCDKzwBP85BGTiionuZrpibThyPUdqn8VWWVzvAVYN2YuGS",
      "block_height": 301792,
      "hash": "th_eWrp3M6REtTmVjGJqEvqXM5ejQ73irAptTtcaqTWNsBYJoxZ5",
      "micro_index": 0,
      "micro_time": 1597894719687,
      "signatures": [
        "sg_E3dyEYE9mrBXbFRN3PjCakpAN1VZbZAuYq8JKVq6ki8vvwsCaDMd947QHBx5pkcwFX1Y1AqiwhcYx5AUpQD1xYoXYHi63"
      ],
      "tx": {
        "account_id": "ak_2AVeRypSdS4ZosdKWW1C4avWU4eeC2Yq7oP7guBGy8jkxdYVUy",
        "fee": 16560000000000,
        "name": "nikita.chain",
        "name_fee": 51422900000000000000,
        "name_id": "nm_2s2gjxQFYzcShL9gva2jWvzZ7mHPe4m6X6pqbyuSipZKCg1DLV",
        "name_salt": 7461157538025441,
        "nonce": 43,
        "type": "NameClaimTx",
        "version": 2
      },
      "tx_index": 14747888
    }
  },
  "name": "nikita.chain",
  "previous": [],
  "status": "auction"
}
```

### `/v2/names/:name/pointers`

This is basically a restricted reply from `/v2/names/:id` endpoint, returning just pointers.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/wwwbeaconoidcom.chain/pointers" | jq '.'
{
  "account_pubkey": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
}
```

### `/v2/names/:name/pointees`

Returns names pointing to a particular pubkey, partitioned into `active` and `inactive` sets.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C/pointees" | jq '.'
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

---

## Contracts

### `/v2/contracts/logs`

A paginable contract log endpoint allows querying of the contract logs using several querying parameters, including:

- `contract_id` - listing only logs emitted by given contract
- `event` - listing only logs emitted by particular event constructor (hex32 encoded blake2b hash)
- `data` - listing only logs which have `data` field matching the provided prefix
- `function` - The name of the function called

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?direction=forward&contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "32049452134983951870486158652299990269658301415986031571975774292043131948665",
        "10000000000000000"
      ],
      "call_tx_hash": "th_2JLGkWhXbEQxMuEYTxazPurKiwGvo5R6vgqjSBw3R8z9F6b4rv",
      "call_txi": 8395071,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://github.com/thepiwo",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    }
  ],
  "next": "contracts/logs/gen/0-370592?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1&page=2"
}
```

The attributes returned on each object are the following:

- `args` - a list of event constructor arguments as big integers. Contract bytecode doesn't contain metadata describing the types of the contract events. As a result, we can only report the binary blobs to the user, which can be either a integer (probably denoting an amount or counter), or public key.
  The integer can be converted to public key (256-bits) binary in Elixir (or Erlang) shell:
  ```
  iex(aeternity@localhost)3> <<32049452134983951870486158652299990269658301415986031571975774292043131948665 :: 256>>
  <<70, 219, 88, 217, 218, 57, 227, 219, 63, 200, 168, 207, 16, 238, 173, 185,
    185, 214, 3, 207, 227, 124, 221, 54, 36, 147, 13, 144, 171, 6, 142, 121>>
  ```

- `call_tx_hash` - hash of contract call transaction which emitted the event log

- `call_txi` - tx index of contract call transaction

- `contract_id` - contract identifier

- `contract_txi` - tx index of contract create transaction

- `data` - decoded (human readable) data field of event log (if any)

- `event_hash` - hex32 encoded blake2b hash of the name of the event constructor
  The source of the contract in question has one of the event log constructors named "TipReceived".
  It's encoded hash can be retrieved as:
  ```
  iex(aeternity@localhost)11> Base.hex_encode32(:aec_hash.blake2b_256_hash("TipReceived"))
  "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0===="
  ```

- `ext_caller_contract_id` - caller contract id, potentially different to `contract_id`, if the contract which emitted the event was called from other contract

- `ext_caller_contract_txi` - tx index of caller's contract create transaction

- `log_idx` - contract call can emit many events. Log idx uniquely identifies the event log inside the contract call.

##### Note for contract writers

From the above, it is obvious that due to the lack of useful metadata in the contract bytecode, browsing contract logs isn't user friendly.

However, logs are still useful for people writing the contracts since they have source code of the contract.

With access to the contract's source code, the developer can:

- identify the event log constructor from the `event_hash` field
- with the constructor, the developer knows the types of `args` for a particular event log
- integer arguments are then understandable literally, while hashes need one more step:
  - after extracting the binary of the argument, this binary should be then passed to:
    ```
    :aeser_api_encoder.encode(<id-type>, extracted-binary)
    ```

    where the `<id-type>` can be one of: `:account_pubkey`, `:contract_pubkey`, `:oracle_pubkey`
    and others, the full list of known types is here (in Erlang syntax):

    https://github.com/aeternity/aeserialization/blob/master/src/aeser_api_encoder.erl#L16

Listing the last (to date) contract log in the chain:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "80808227038564992079558295896388926841596253273977977325246416786468530750284",
        "23245441236723951035912846601319239080044515685575576534240736154129181748855",
        "966628800000000000"
      ],
      "call_tx_hash": "th_2vDNSLGyBdBNPmyfWtfHEAH2PdJh7t39G3a6JtM4ByfYD1LT1V",
      "call_txi": 19626064,
      "contract_id": "ct_2MgX2e9mdM3epVpmxLQim7SAMF2xTbid4jtyVi4WiLF3Q8ZTRZ",
      "contract_txi": 17708111,
      "data": "",
      "event_hash": "48U3JOKTVTI6FVMTK2BLHM8NG72JEBG93VS6MENPSC8E71IM5FNG====",
      "ext_caller_contract_id": "ct_2M4mVQCDVxu6mvUrEue1xMafLsoA1bgsfC3uT95F3r1xysaCvE",
      "ext_caller_contract_txi": 17707096,
      "log_idx": 2
    }
  ],
  "next": "/v2/contracts/logs?cursor=68PJACHK74O3E91J60QJADHG6OR28HA96P258MAL6KRJAKQ7A0RLEDAL8D65CKIN95C52I23AH7KOKAA8GRJ8HQN9TC5KD2D957KGGIJAT350M2H7KUJQF9460I0&limit=1",
  "prev": null
}
```

Listing contract logs in range between generations 200000 and 210000:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?scope=gen:200000-210000&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "48550576960427288418928503238185419255781131458428297160617859112449977313818",
        "1000000000000000000"
      ],
      "call_tx_hash": "th_2BjrnHaRHo196AHtpMHV4QUiJqDi6UjfsA5pbPgTGhKpQuB67N",
      "call_txi": 7004806,
      "contract_id": "ct_cT9mSpx9989Js39ag45fih2daephb7YsicsvNdUdEB156gT5C",
      "contract_txi": 6589581,
      "data": "https://github.com/aeternity",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_cT9mSpx9989Js39ag45fih2daephb7YsicsvNdUdEB156gT5C",
      "ext_caller_contract_txi": 6589581,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?cursor=6CS34DHK6KQI8D1G60O38DPP4H2KIDI4AHCLAD9N6L9KEK1NASQLAGQCAP95EIAOA5446L2F9H8KKH1N6H3LEJQOB8Q4QIAF91156LQ6A1C52F9T7KUI8C14&limit=1&scope=gen%3A200000-210000",
  "prev": null
}
```

Listing contract logs in generation 250109 only:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?scope=gen:250109&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "113825637927817399496888947973485901133216730124575464244310341957325543404011",
        "100000000000000000"
      ],
      "call_tx_hash": "th_22pciXRFnEieCSMEbcEPEfHdxvJobJt2UoCtXXiQ3pnDn6kvaz",
      "call_txi": 10788741,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://twitter.com/LeonBlockchain",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?cursor=6CS34DHK6KQI8D1G60O38DPP4H2KIDI4AHCLAD9N6L9KEK1NASQLAGQCAP95EIAOA5446L2F9H8KKH1N6H3LEJQOB8Q4QIAF91156LQ6A1C52F9T7KUI8C14&limit=1&scope=gen%3A250109",
  "prev": null
}
```

Listing contract logs from transaction index 15000000 downto 5000000 - e.g. backwards (note descending call_txi):

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?scope=txi:15000000-5000000&limit=2" | jq '.'
{
  "data": [
    {
      "args": [
        "62059066751890548769948246095111340843449817566010565188117840814896942849080",
        "585892500000000000000"
      ],
      "call_tx_hash": "th_kNDMha7svd7BefFBzGgLqzZAvFpvCSf3KebML1ehBL681ohyc",
      "call_txi": 14990154,
      "contract_id": "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6",
      "contract_txi": null,
      "data": "0X0129E84285A6E158050774C02D0CC0279A952812",
      "event_hash": "8U30JKGH96FU11A2BB23RPC7BQILKJVEV1HS79QF2QQLMRTN72UG====",
      "ext_caller_contract_id": "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6",
      "ext_caller_contract_txi": null,
      "log_idx": 0
    },
    {
      "args": [
        "40622116278729278568318020744060411462094505710435719316947449635041473609173",
        "200000000000000000"
      ],
      "call_tx_hash": "th_2Hu1vp599wdSHKQdX1Hpn6mj9PhQLwBTnqybYqEdzkUrcjKA7J",
      "call_txi": 14984615,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://kryptokrauts.com/log/superhero-a-truly-decentralized-social-tipping-platform",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?cursor=68PJACHK74O3E91J60QJAD9N6CQI8HA96P258MAL6KRJAKQ7A0RLEDAL8D65CKIN95C52I23AH7KOKAA8GRJ8HQN9TC5KD2D957KGGIJAT350M2H7KUJQF9460I0&limit=2&scope=txi%3A15000000-5000000",
  "prev": null
}
```

Listing latest logs for given contract

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2" | jq '.'
{
  "data": [
    {
      "args": [
        "87569133758291964643644139664803946495433064832095920406619813370506210782355",
        "120000000000000000"
      ],
      "call_tx_hash": "th_2rQFbvkR2rxvBQLWt4WPUPiSViES8aKDBVDraF4mogdZsVTJSQ",
      "call_txi": 19625942,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://www.youtube.com/watch?v=iLQzaLr1enE",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    },
    {
      "args": [
        "19315768272296812419334917756530784329195878521494173087129733615253420217233",
        "52300000000000000000"
      ],
      "call_tx_hash": "th_JgxLwr7WszXNT5tU1ngc6fJJyxTywcLjWxXy8sqrpX7r7byCQ",
      "call_txi": 19625814,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://superhero.com/",
      "event_hash": "ATPGPVQP8277UG86U0JDA2CPFKQ1F28A51VAG9F029836CU1IG80====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=70PJICHN6OR28CPG6GR3GDHK6OI5AH2MACRKOM9LB58KKD9L9DD3AMIKA92KGM269LCKAL9NA12K4DA69HCKGCQC88PKIDHN6TCLAKA2915LKK9T7KUJQ91G4G&limit=2",
  "prev": null
}
```

Listing first logs where data field points to `aeternity.com`:
(The value of data parameter needs to be URL encoded, which is not visible in this example)

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?direction=forward&data=aeternity.com&limit=2" | jq '.'
{
  "data": [
    {
      "args": [
        "69318356919715896655612698359975736845612647472784537635207689589288608801665"
      ],
      "call_tx_hash": "th_29wEBiUVommkJJqtWxczsdTViBSHsCxsQMtyYZb3hju4xW6eFS",
      "call_txi": 14749000,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "aeternity.com",
      "event_hash": "K3LIVBOTOG9TTAPTPJH47N5CO4KVF41T5BO7RB1R8UVVOKG17APG====",
      "ext_caller_contract_id": "ct_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
      "ext_caller_contract_txi": 11204400,
      "log_idx": 0
    },
    {
      "args": [
        "69318356919715896655612698359975736845612647472784537635207689589288608801665"
      ],
      "call_tx_hash": "th_nvrmo5YmrWUW9pr2ohiPWB6FHgok9owi5xbLMpV2pHYvECxTD",
      "call_txi": 14749001,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "aeternity.com",
      "event_hash": "K3LIVBOTOG9TTAPTPJH47N5CO4KVF41T5BO7RB1R8UVVOKG17APG====",
      "ext_caller_contract_id": "ct_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
      "ext_caller_contract_txi": 11204400,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?cursor=70PJICHN6OR28C9K6SQ3IC1L74I5EDQH6OP4IHQ29TAJ6M2C9L8JCJA48P444GIQ99BK6KHK6SP54KA6B124KJAF8P6KQKPM6944MKAL90R3CG9T7KUJQ91G4HGMAT35E9N6IT3P5PHMUR8&data=aeternity.com&direction=forward&limit=2",
  "prev": null
}
```

Listing the last "TipReceived" event:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/logs?event=TipReceived&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "87569133758291964643644139664803946495433064832095920406619813370506210782355",
        "120000000000000000"
      ],
      "call_tx_hash": "th_2rQFbvkR2rxvBQLWt4WPUPiSViES8aKDBVDraF4mogdZsVTJSQ",
      "call_txi": 19625942,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "data": "https://www.youtube.com/watch?v=iLQzaLr1enE",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "ext_caller_contract_txi": 8392766,
      "log_idx": 0
    }
  ],
  "next": "/v2/contracts/logs?cursor=70PJICHN6OR28CPG64R3ADHN6CI5EDQH6OP4IHQ29TAJ6M2C9L8JCJA48P444GIQ99BK6KHK6SP54KA6B124KJAF8P6KQKPM6944MKAL90R3CG9T7KUJQ91G4G&event=TipReceived&limit=1",
  "prev": null
}
```

### `/v2/contracts/calls`

A running contract can call other functions during execution. These calls are recorded and can be queried later.

The query accepts following filters:

- `fname` - The prefix of the name of the function
- `create_txi` - The creation txi for a given contract
- ID field - Any field belonging to the contract call transaction

#### Using contract id

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/calls?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_25eLkLkkMDRg5Sau1ezeNteAXxzAnfECqeN318hTFLifozJkpt",
      "call_tx_hash": "th_gTNykxuM2MJ4D2Y7L5EoU7wKprmM6rLmAKe2yaBrjbNudMeSq",
      "call_txi": 20308637,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "function": "Call.amount",
      "height": 403795,
      "internal_tx": {
        "amount": 100000000000000,
        "fee": 0,
        "nonce": 0,
        "payload": "ba_Q2FsbC5hbW91bnTau3mT",
        "recipient_id": "ak_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
        "sender_id": "ak_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "type": "SpendTx",
        "version": 1
      },
      "local_idx": 5,
      "micro_index": 9
    }
  ],
  "next": "/v2/contracts/calls?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=6CO3ACPK6GRJI91J4GS36E9I6SR3C9144GMJ2C1G&limit=1",
  "prev": null
}
```

Using function prefix

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/calls?direction=forward&function=Oracle&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2XAPbotBm5qgkWn165g3J7eRsfV9r5tEwSEqS3rggR6b9fRbW",
      "call_tx_hash": "th_4q3cLesnXqSSH3HmecGMSUuZZNKsue8rGMACtCRmFpZtpAXPH",
      "call_txi": 8404781,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "function": "Oracle.query",
      "height": 219107,
      "internal_tx": {
        "fee": 0,
        "nonce": 0,
        "oracle_id": "ok_2ChQprgcW1od3URuRWnRtm1sBLGgoGZCDBwkyXD1U7UYtKUYys",
        "query": "ak_y87WkN4C4QevzjTuEYHg6XLqiWx3rjfYDFLBmZiqiro5mkRag;https://github.com/thepiwo",
        "query_fee": 20000000000000,
        "query_ttl": {
          "type": "delta",
          "value": 20
        },
        "response_ttl": {
          "type": "delta",
          "value": 20
        },
        "sender_id": "ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs",
        "type": "OracleQueryTx",
        "version": 1
      },
      "local_idx": 0,
      "micro_index": 0
    }
  ],
  "next": "/v2/contracts/calls?cursor=70Q30D1N70OI8C945KOJ0C144H53AMI78DCJ6JADALC4GGPL9H34UIHKA4I2QC9G60&direction=forward&function=Oracle&limit=1",
  "prev": null
}
```

Using ID field

Following ID fields are recognized: `account_id`, `caller_id`, `channel_id`, `commitment_id`, `from_id`, `ga_id`, `initiator_id`, `name_id`, `oracle_id`, `owner_id`, `payer_id`, `recipient_id`, `responder_id`, `sender_id`, `to_id`.

Contract_id field is inaccessible via this lookup, as when present in query, it filters only contracts with given contract id and doesn't look into internal transaction's fields.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/contracts/calls?recipient_id=ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2Mp1FfJyEaQUYbBKywWb6kWGm1KoTEyc4SZgt7oA7orz9BpSLD",
      "call_tx_hash": "th_XnXh22b9XsXGPEE9ZJwm4E9FuMhv47Z2ogQo6Lgt4npEwVF9W",
      "call_txi": 8820436,
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "contract_txi": 8392766,
      "function": "Call.amount",
      "height": 224666,
      "internal_tx": {
        "amount": 80000000000000,
        "fee": 0,
        "nonce": 0,
        "payload": "ba_Q2FsbC5hbW91bnTau3mT",
        "recipient_id": "ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs",
        "sender_id": "ak_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "type": "SpendTx",
        "version": 1
      },
      "local_idx": 4,
      "micro_index": 11
    }
  ],
  "next": "/v2/contracts/calls?cursor=70S34C1K68S28D145KOJ0C14A93KQGHK9D3K4I258H546JQC99A5IL25AHCL6GPN9T4KIMIB6D2KSKI88P4LKL2M6923AJA16T65ILPJ698I891I&limit=1&recipient_id=ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs",
  "prev": null
}
```

---

## Internal transfers

### `/v2/transfers`

During the operation of the node, several kinds of internal transfers happen which are not visible on general transaction ledger.

Besides specifying of scope and direction as with other streaming endpoints (via forward/backward or gen), the query accepts following filters:

- `kind`. At the moment, following kinds of transfers can be queried:
	- `fee_spend_name` (fee for placing bid to the name auction)
  - `fee_refund_name` (returned fee when the new name bid outbids the previous one in the name auction)
	- `fee_lock_name` (locked fee of the name auction winning
	- `reward_oracle` (reward for the operator of the oracle (on transaction basis))
  - `reward_block` (reward for the miner (on block basis))
  - `reward_dev` (reward for funding of the development (on block basis))
  - `accounts_minerva`, `accounts_fortuna` and `accounts_lima` (added on hardforks including migrated ERC20 amounts)

	It it possible to provide just a prefix of the kind in interest, e.g.: "reward" will return all rewards, "fee" will return all fees,
  "accounts" will return credits after hardforks.

- `account` - account which received rewards or that was charged fees or that received tokens after a hardfork migration.

Listing internal transfers in range

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/transfers?scope=gen:50002-70000&limit=3" | jq '.'
{
  "data": [
    {
      "account_id": "ak_542o93BKHiANzqNaFj6UurrJuDuxU61zCGr9LJCwtTUg34kWt",  # target account
      "amount": 218400000000000,                                             # amount of tokens
      "height": 50002,                                                       # generation height
      "kind": "reward_block",                                                # kind of transfer
      "ref_txi": null                                                        # reference tx id (if any)
    },
    {
      "account_id": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "amount": 407000327600000000000,
      "height": 50002,
      "kind": "reward_block",
      "ref_txi": null
    },
    {
      "account_id": "ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J",
      "amount": 3,
      "height": 50002,
      "kind": "fee_lock_name",
      "ref_txi": 1516090
    }
  ],
  "next": "/v2/transfers?scope=gen:50002-70000&cursor=6KO30C1I5GOJAC9M60SJ2936CLILUR3FCDLLURJ1DLII85B36T6B4BDUUA3PPOSNFT2NRAQ67SAGJVNC35N46VHNTU4SU3V14GOJAC9M60SJ2&limit=3",
  "prev": null
}
```

Listing internal transfers of a specific kind

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/transfers?direction=forward&kind=reward_dev&limit=2" | jq '.'
{
  "data": [
    {
      "account_id": "ak_2KAcA2Pp1nrR8Wkt3FtCkReGzAi8vJ9Snxa4PcmrthVx8AhPe8",
      "amount": 37496010998100000000,
      "height": 90981,
      "kind": "reward_dev",
      "ref_txi": null
    },
    {
      "account_id": "ak_2KAcA2Pp1nrR8Wkt3FtCkReGzAi8vJ9Snxa4PcmrthVx8AhPe8",
      "amount": 37496003679840000000,
      "height": 90982,
      "kind": "reward_dev",
      "ref_txi": null
    }
  ],
  "next": "/v2/transfers/forward?cursor=74O3IE1J5GMJ293ICLRM2SJ4BTI6ATH4LJOO0LBKD1ROVHB90J0E1JU8HBJ58RP6B4GUU5E9MUST24PSDM428B9H&kind=reward_dev&limit=2",
  "prev": null
}
```

Listing internal transfers related to specific account

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/transfers?account=ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J&limit=1" | jq '.'
{
  "data": [
    {
      "account_id": "ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J",
      "amount": 3,
      "height": 51366,
      "kind": "fee_lock_name",
      "ref_txi": 1680384
    }
  ],
  "next": "/v2/transfers?account=ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J&cursor=6KOJ4CHH5GOJCDHG70PJG936CLILUR3FCDLLURJ1DLII83R2BN0S5LH5TCGCSOIPLQM6D3RI7C7ICPVL44G939G2DR91PR6U4GOJCDHG70PJG&limit=1",
  "prev": null
}
```

---

## Oracles

There are several endpoints for fetching information about the oracles.

Oracles in Aeternity blockchain have a lifecycle formed by several types of transactions, similar to the Name objects.

For the same reason as Names, all oracle endpoints support `expand` parameter (either set to `true` or without value), which will replace the transaction indices with the JSON body of the transaction detail.


### `/v2/oracle/:id`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/oracles/ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM" | jq '.'
{
  "active": false,
  "active_from": 4660,
  "expire_height": 6894,
  "extends": [
    11025
  ],
  "format": {
    "query": "string",
    "response": "string"
  },
  "oracle": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
  "query_fee": 20000,
  "register": 11023
}
```

Provided `expand` parameter replaces transaction indices in `extends` and `register` fields:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/oracles/ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM?expand" | jq '.'
{
  "active": false,
  "active_from": 4660,
  "expire_height": 6894,
  "extends": [
    {
      "block_hash": "mh_2CbcGSVU1PaFgpvdv3akxUk5aLkPVtqXrYPYcURr5RnPMzBzic",
      "block_height": 4662,
      "hash": "th_rPNXqxHg7JVSe7LRUy2KyEXp6west8JgBzzKGk8PPxvCh8p1h",
      "micro_index": 0,
      "micro_time": 1544194970900,
      "signatures": [
        "sg_a27euq6jBYUJEadCPbxDzAztHmvLXpFEqrB7md2wNKqmUZur7urmiBAYRiHvwcFz3ZbNKb3ESyA4vSTvDam4e6QTHkCGU"
      ],
      "tx": {
        "fee": 20000,
        "nonce": 196,
        "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
        "oracle_ttl": {
          "type": "delta",
          "value": 1000
        },
        "type": "OracleExtendTx",
        "version": 1
      },
      "tx_index": 11025
    }
  ],
  "format": {
    "query": "string",
    "response": "string"
  },
  "oracle": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
  "query_fee": 20000,
  "register": {
    "block_hash": "mh_25pDFuKkhF6zzAhy2DEwY5ALYpM4u5UKVmqgvNTgZ2ZDLqDbHr",
    "block_height": 4660,
    "hash": "th_2SLFNYk5s5u5tRD4Bqx6pSc1mysZMsCr3szbx55nKgVBQSiZv2",
    "micro_index": 0,
    "micro_time": 1544194831238,
    "signatures": [
      "sg_JwZ2KgLAZvDBgsHVccqYuhmwuCvLnMrxNrZ7y7jmA3NxZUaaoBGcxNXd64MTX142JXMbaLAirZrRh7qf6f5XXp3iN5Qao"
    ],
    "tx": {
      "abi_version": 0,
      "account_id": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
      "fee": 20000,
      "nonce": 195,
      "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
      "oracle_ttl": {
        "type": "delta",
        "value": 1234
      },
      "query_fee": 20000,
      "query_format": "string",
      "response_format": "string",
      "type": "OracleRegisterTx",
      "version": 1
    },
    "tx_index": 11023
  }
}
```

### `/v2/oracles`

There is only one paginable endpoints for listing oracles: `/v2/oracles` - for listing oracles, with filters that include the `scope` (e.g. `gen:100-200`) or state (`active` or `inactive`).

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/oracles?direction=forward&limit=1&expand" | jq '.'
{
  "data": [
    {
      "active": false,
      "active_from": 4608,
      "expire_height": 5851,
      "extends": [
        {
          "block_hash": "mh_rKmT9rDDFNSNfS4HFrRjNbFqszCvTirHfH2JAFCrhB6x6s85u",
          "block_height": 4609,
          "hash": "th_2pJmkk8FRsSNU1aH9H7eMHErTVzJTGnE5xiTsVgyhMjPzdEemZ",
          "micro_index": 0,
          "micro_time": 1544185907144,
          "signatures": [
            "sg_8tvreNZhhV5a1ZVo7CMiRGbjbgpj65XBa8wttqQmuXRD13FL1RAgfU5fgWkdyxsQUop1dJUqC3bV7ZvbRyvQkDo7NamGT"
          ],
          "tx": {
            "fee": 20000,
            "nonce": 2,
            "oracle_id": "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5",
            "oracle_ttl": {
              "type": "delta",
              "value": 9
            },
            "type": "OracleExtendTx",
            "version": 1
          },
          "tx_index": 8989
        }
      ],
      "format": {
        "query": "the query spec",
        "response": "the response spec"
      },
      "oracle": "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5",
      "query_fee": 20000,
      "register": {
        "block_hash": "mh_uQMxaJ6ajKnMsW2M3QqgH1FchXGNbZriRceVggoTnUEGdgSHq",
        "block_height": 4608,
        "hash": "th_tboa3XizqaAW3FUx4SxzT2xmuXDYRarQqjZiZ384u4oVDn1EN",
        "micro_index": 0,
        "micro_time": 1544185806672,
        "signatures": [
          "sg_A7MGMsQxY9VTCxvBnuStmNsDSADf9H7t57c79hWotFC69e1xpcV78QXJfKoMFSgn1s7RErNksFyKcrihwYifCELnEQFQ3"
        ],
        "tx": {
          "abi_version": 0,
          "account_id": "ak_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5",
          "fee": 20000,
          "nonce": 1,
          "oracle_id": "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5",
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
        "tx_index": 8916
      }
    }
  ],
  "next": "/oracles?cursor=6894-ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM&direction=forward&expand=true&limit=1",
  "prev": null
}
```

Inactive oracles

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/oracles?state=inactive&limit=1" | jq '.'
{
  "data": [
    {
      "active": false,
      "active_from": 307850,
      "expire_height": 308350,
      "extends": [],
      "format": {
        "query": "string",
        "response": "string"
      },
      "oracle": "ok_sezvMRsriPfWdphKmv293hEiyeyUYSoqkWqW7AcAuW9jdkCnT",
      "query_fee": 20000000000000,
      "register": 15198855
    }
  ],
  "next": "/v2/oracles?state=inactive&cursor=507223-ok_26QSujxMBhg67YhbgvjQvsFfGdBrK9ddG4rENEGUq2EdsyfMTC&direction=backward&expand=false&limit=1",
  "prev": null
}
```

Active oracles

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/oracles?state=active&limit=1&expand" | jq '.'
{
  "data": [
    {
      "active": true,
      "active_from": 289005,
      "expire_height": 10289005,
      "extends": [],
      "format": {
        "query": "query",
        "response": "response"
      },
      "oracle": "ok_qJZPXvWPC7G9kFVEqNjj9NAmwMsQcpRu6E3SSCvCQuwfqpMtN",
      "query_fee": 0,
      "register": {
        "block_hash": "mh_2f1gyBmtMMb8Sd3kbSu95cADRMwsYE8171KXP4W8wa2osRp4tZ",
        "block_height": 289005,
        "hash": "th_K5aPLdEN4H6QduiFtqdkv61gUCvaQpDjX3z9pHKNopD8F65LJ",
        "micro_index": 20,
        "micro_time": 1595571086808,
        "signatures": [
          "sg_CW3T2W6Ryi2kcDcSTeuwvL8xGhKYUDnGHygBCPLrF2aqfWA1RiybKqRRafrctK4c9vvL9DS9kCYzWkWSmD8mN9g6yhQPG"
        ],
        "tx": {
          "abi_version": 0,
          "account_id": "ak_qJZPXvWPC7G9kFVEqNjj9NAmwMsQcpRu6E3SSCvCQuwfqpMtN",
          "fee": 1842945000000000,
          "nonce": 1,
          "oracle_id": "ok_qJZPXvWPC7G9kFVEqNjj9NAmwMsQcpRu6E3SSCvCQuwfqpMtN",
          "oracle_ttl": {
            "type": "delta",
            "value": 10000000
          },
          "query_fee": 0,
          "query_format": "query",
          "response_format": "response",
          "ttl": 289505,
          "type": "OracleRegisterTx",
          "version": 1
        },
        "tx_index": 13749762
      }
    }
  ],
  "next": "/v2/oracles?state=active&cursor=1289003-ok_f9vDQvr1cFAQAesYA16vjvBX9TFeWUB4Gb7WJkwfYSkL1CpDx&direction=backward&expand=true&limit=1",
  "prev": null
}
```

---

## Channels

### `/v2/channels`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/channels?limit=1" | jq '.'
{
  "data": [
    {
      "amount": 20000000000001,
      "channel": "ch_vpYXyMJZDF8Rdc3EZFvLdKYrWZKsbs1hKXHXMAczeV8MmDPkK",
      "initiator": "ak_2BUfk9dHtn2YKuBe6uY9f4qD94xKETA6w9MGAYyJc5weiUUXhy",
      "last_updated_height": 141956,
      "last_updated_tx_hash": "th_tuTDcp7boNK7MzcWS8pForWJt5683qdVcJtETcJPmHsPgCXvd",
      "last_updated_tx_type": "ChannelCreateTx",
      "responder": "ak_2BUfk9dHtn2YKuBe6uY9f4qD94xKETA6w9MGAYyJc5weiUUXhy",
      "state_hash": "st_Wwxms0IVM7PPCHpeOXWeeZZm8h5p/SuqZL7IHIbr3CqtlCL+",
      "updates_count": 1
    }
  ],
  "next": "/v2/channels?cursor=141956-ch_hhqtLjXn9h31Sa6WTNxTANC1zG3WxUzCss1HnJSjovP4pnVUK&limit=1",
  "prev": null
}
```

## AEX9 tokens

There are 2 endpoints for listing tokens as defined by AEX9 (https://github.com/aeternity/AEXs/blob/master/AEXS/aex-9.md)

- `/aex9/by_name` - for listing tokens sorted by name
- `/aex9/by_symbol` - for listing tokens sorted by symbol

These endpoints optional parameters:

- `all` - for listing all contract creations for a token, not just the last one (default: false)
- `prefix` OR `exact` - for listing tokens with the name or symbol, which are matching either by prefix, or exactly

### AEX9 tokens by name

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/by_name" | jq '.'
[
  {
    "decimals": 18,
    "name": "911058",
    "symbol": "SPH",
    "txi": 12361891
  },
  {
    "decimals": 18,
    "name": "AAA",
    "symbol": "AAA",
    "txi": 15672306
  },
  {
    "decimals": 18,
    "name": "AAA name",
    "symbol": "AAA",
    "txi": 12287008
  },
  {
    "decimals": 18,
    "name": "ABB",
    "symbol": "ABB",
    "txi": 12287175
  },
  {
    "decimals": 18,
    "name": "ABC",
    "symbol": "ABC",
    "txi": 17742955
  },
  {
    "decimals": 18,
    "name": "ABC Test token",
    "symbol": "ABC",
    "txi": 12287522
  },
  {
    "decimals": 18,
    "name": "AE Genesis",
    "symbol": "AEG",
    "txi": 5476384
  },
  ...
```

Or, listing tokens with prefix = "ae", along with all contract create transaction ids:

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/by_name?prefix=ae" | jq '.'
[
  {
    "decimals": 18,
    "name": "ae",
    "symbol": "ae",
    "txi": 9434572
  },
  {
    "decimals": 18,
    "name": "ae",
    "symbol": "ae",
    "txi": 9434926
  },
  {
    "decimals": 18,
    "name": "ae",
    "symbol": "ae",
    "txi": 9438753
  },
  {
    "decimals": 18,
    "name": "aea",
    "symbol": "aea",
    "txi": 9434498
  },
  {
    "decimals": 18,
    "name": "aeaeb",
    "symbol": "aeaeb",
    "txi": 9770669
  },
  {
    "decimals": 18,
    "name": "aeb",
    "symbol": "aeb",
    "txi": 9770640
  },
  {
    "decimals": 18,
    "name": "aeb",
    "symbol": "aeb",
    "txi": 9771055
  },
  {
    "decimals": 18,
    "name": "aeblievers",
    "symbol": "AEB",
    "txi": 12407023
  },
  {
    "decimals": 18,
    "name": "aeblievers",
    "symbol": "AEB",
    "txi": 12407153
  }
]
```

Note, that for both endpoints - `by_name` and `by_symbol` - if the querying part (`prefix` or `exact`) contains unicode or a space character, it needs to be URL encoded:

```
$ curl -s "https://testnet.aeternity.io/mdw/aex9/by_name?exact=%F0%9D%9D%BA%20Token" | jq '.'
[
  {
    "contract_id": "ct_eW2aiba4vXEwmyGEu7vxvDt6396Zvr6jQYUcoyfe9W9V7KGqr",
    "contract_txi": 13321748,
    "decimals": 18,
    "name": "𝝺 Token",
    "symbol": "𝝺"
  },
  {
    "contract_id": "ct_2vsdt2dpbx9MQGcDytedT8sL2UjhYzp6Le3ZSQiKuLDgzAhuWT",
    "contract_txi": 13321799,
    "decimals": 18,
    "name": "𝝺 Token",
    "symbol": "𝝺"
  }
]
```

### AEX9 tokens by symbol

Example with exact parameter:
```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/by_symbol?exact=TNT" | jq '.'
[
  {
    "contract_id": "ct_6ZuwbMgcNDaryXTnrLMiPFW2ogE9jxAzz1874BToE81ksWek6",
    "contract_txi": 8537557,
    "decimals": 18,
    "name": "Test Network",
    "symbol": "TNT"
  }
]
```

## AEX9 contract balances

There are 3 endpoints for listing token balance of the contract for given account:

- `/aex9/balance/:contract_id/:account_id` - shows account balance at the current top of the chain

- `/aex9/balance/hash/:blockhash/:contract_id/:account_id` - shows account balance at given block

- `/aex9/balance/gen/:range/:contract_id/:account_id` - show account balances at given height or range of heights


Additional 3 endpoints can be used for showing ALL balances for a given contract:

- `/aex9/balances/:contract_id` - shows all balances at the current top of the chain

- `/aex9/balances/hash/:blockhash/:contract_id` - shows all balances at given block

- `/aex9/balances/gen/:range/:contract_id` - shows all balances at given height or range of heights

Lastly, 3 endpoints can show balances over all contracts for a given account:

- `/aex9/balances/gen/:height/account/:account_id` - shows balances of all contracts at height for account
- `/aex9/balances/hash/:blockhash/account/:account_id` - shows balances of all contracts at blockhash for account
- `/aex9/balances/account/:account_id` - shows token balances of all contracts for given account at the current top of the chain


Endpoints which use the current top of the chain:
- `/aex9/balance/:contract_id/:account_id`
- `/aex9/balances/:contract_id`
- `/aex9/balances/account/:account_id`

use the latest key block as a source of information for returning of the balances.

If the user wishes, she can provide a query parameter `top` to the query.
Its presence or binding it to `true` will use the latest micro block for retrieving balances of the contract(s).


### AEX9 contract balance for account

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balance/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA/ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" | jq '.'
{
  "account_id": "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
  "amount": 49999999999906850000000000,
  "block_hash": "kh_2QevaXY7ULF5kTLsddwMzzZmBYWPgfaQbg2Y8maZDLKJaPhwDJ",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "height": 351666
}
```

### AEX9 contract balance for account at block

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balance/hash/mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA/ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" | jq '.'
{
  "account_id": "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
  "amount": 49999999999906850000000000,
  "block_hash": "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "height": 350622
}
```

### AEX9 contract balance for account at height or range of heights

Single integer identifies the generation:
```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balance/gen/350700/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA/ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" | jq '.'
{
  "account_id": "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "range": [
    {
      "amount": 49999999999906850000000000,
      "block_hash": "kh_2dhhsiRAUt1319MyDWLSq2WeKvCXfWoeaaosqNhyHvKsK8dZqJ",
      "height": 350700
    }
  ]
}
```

A range can be provided as well:

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balance/gen/350620-350623/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA/ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" | jq '.'
{
  "account_id": "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "range": [
    {
      "amount": 49999999999906850000000000,
      "block_hash": "kh_2qXeiNrHh3U1ZfyUifwLVf9e7riyv6Rgp7nJV9bHoQb2vugn8c",
      "height": 350620
    },
    {
      "amount": 49999999999906850000000000,
      "block_hash": "kh_29yHf38wCMNdqEsDVQTBSx6A7W8oZedQqTBQuAPN9JiXYxwx2o",
      "height": 350621
    },
    {
      "amount": 49999999999906850000000000,
      "block_hash": "kh_21P5Y1rv97MZruUSC9mTRmscFxAFnFi4HjUAoqmqHfmoS1Np4b",
      "height": 350622
    },
    {
      "amount": 49999999999906850000000000,
      "block_hash": "kh_2Ya2fM9brRoBQpxR3xz4K39hTqmjiMJ7GfSu3LbCmxLYjX5cHV",
      "height": 350623
    }
  ]
}
```

### AEX9 contract balances

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA" | jq '.'
{
  "amounts": {
    "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
    "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
    "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
    "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
  },
  "block_hash": "kh_2hXEoFTmMphpvCmvdvQTZtGu9a3RndL5fSvVqzKBs2DSNJjQ2V",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "height": 351669
}
```

### AEX9 contract balances at block

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/hash/kh_2Ya2fM9brRoBQpxR3xz4K39hTqmjiMJ7GfSu3LbCmxLYjX5cHV/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA" | jq '.'
{
  "amounts": {
    "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
    "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
    "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
    "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
  },
  "block_hash": "kh_2Ya2fM9brRoBQpxR3xz4K39hTqmjiMJ7GfSu3LbCmxLYjX5cHV",
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "height": 350623
}
```

### AEX9 contract balances at height or range of heights

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/gen/350580/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA" | jq '.'
{
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "range": [
    {
      "amounts": {
        "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
        "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
        "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
        "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
      },
      "block_hash": "kh_2Jv6ZekDGipPQWrZKitdqtbxgx6bGUMNvkSPmi8pvpheGynKLu",
      "height": 350580
    }
  ]
}
```

Or, with range:

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/gen/350600-350603/ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA" | jq '.'
{
  "contract_id": "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
  "range": [
    {
      "amounts": {
        "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
        "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
        "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
        "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
      },
      "block_hash": "kh_wCXiE3TTbQSCboPictnY7KXH5qmm8kjUoWHJNNqM25H4BWSW8",
      "height": 350600
    },
    {
      "amounts": {
        "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
        "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
        "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
        "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
      },
      "block_hash": "kh_wGwxc8bMfLZqSAXDGLAv7XeFs9afNxGGZ2jpBRvMQ9pWj14pj",
      "height": 350601
    },
    {
      "amounts": {
        "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
        "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
        "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
        "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
      },
      "block_hash": "kh_avZRszDXggtiVk8oMCjZmd92JVga6Ng6BRAtuPPdaj2ntZwN6",
      "height": 350602
    },
    {
      "amounts": {
        "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6": 4050000000000,
        "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK": 8100000000000,
        "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4": 81000000000000,
        "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48": 49999999999906850000000000
      },
      "block_hash": "kh_2QBikn2KuxBgbBdzJBmbydmW5dRNHEDdCKU8Psb19MuWuNLZwf",
      "height": 350603
    }
  ]
}
```

### AEX 9 contract balances for account

In all account specific balance endpoints, the values of `block_hash`/`tx_hash`/`tx_index` show the last time of when (in what block, transaction) was the balance in a listed contract updated.

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/account/ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4" | jq '.'
[
  {
    "amount": 5e+26,
    "block_hash": "mh_yDKBNdZdZ7q2n5gr8SryP6XJCnTWcd8rcAaeTZ8mY5TftZK9J",
    "contract_id": "ct_2vJBVkrBbmZjxovPq21p7Udfp1s5KCaLaixB8MNW41owVgJtWR",
    "height": 334200,
    "tx_hash": "th_DEaWuq3966N5DPPwS1x1t4ibT22WJJAMzi85ntrrD6MpygRYM",
    "tx_index": 17153024,
    "tx_type": "contract_create_tx"  # account was creator of the contract
  },
  {
    "amount": 0,
    "block_hash": "mh_kkKtNk2GAgJKjar9ro6amr6AugG9eLP9RL7wUSmdRqjBZrRq9",
    "contract_id": "ct_2jDFr1iaKxKrftiFge6gPsfgsZnwNLgu1icScBfhuzpgX1faXM",
    "height": 334268,
    "tx_hash": "th_26xCyuKpvs3CTUxTbycDXDQbYt2xQbd6Rf2uJEWSNDAyFSucNK",
    "tx_index": 17157444,
    "tx_type": "contract_call_tx"    # account received tokens during contract call
  },
  ...
]
```

The `top` parameter at this endpoint, when present, can show the most up to date balance as a result of contract call, but can't show a account balance of freshly created AEX9 contract.

The awareness that the contract is created by some account comes from syncing, which is inherently one generation behind the top of the chain.


### AEX 9 contract balances for account at height

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/gen/334201/account/ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4" | jq '.'
[
  {
    "amount": 5e+26,
    "block_hash": "mh_yDKBNdZdZ7q2n5gr8SryP6XJCnTWcd8rcAaeTZ8mY5TftZK9J",
    "contract_id": "ct_2vJBVkrBbmZjxovPq21p7Udfp1s5KCaLaixB8MNW41owVgJtWR",
    "height": 334200,
    "tx_hash": "th_DEaWuq3966N5DPPwS1x1t4ibT22WJJAMzi85ntrrD6MpygRYM",
    "tx_index": 17153024,
    "tx_type": "contract_create_tx"
  }
]
```

### AEX 9 contract balances for account at block

```
$ curl -s "https://mainnet.aeternity.io/mdw/aex9/balances/hash/mh_kkKtNk2GAgJKjar9ro6amr6AugG9eLP9RL7wUSmdRqjBZrRq9/account/ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4" | jq '.'
[
  {
    "amount": 5e+26,
    "block_hash": "mh_yDKBNdZdZ7q2n5gr8SryP6XJCnTWcd8rcAaeTZ8mY5TftZK9J",
    "contract_id": "ct_2vJBVkrBbmZjxovPq21p7Udfp1s5KCaLaixB8MNW41owVgJtWR",
    "height": 334200,
    "tx_hash": "th_DEaWuq3966N5DPPwS1x1t4ibT22WJJAMzi85ntrrD6MpygRYM",
    "tx_index": 17153024,
    "tx_type": "contract_create_tx"
  },
  {
    "amount": 0,
    "block_hash": "mh_kkKtNk2GAgJKjar9ro6amr6AugG9eLP9RL7wUSmdRqjBZrRq9",
    "contract_id": "ct_2jDFr1iaKxKrftiFge6gPsfgsZnwNLgu1icScBfhuzpgX1faXM",
    "height": 334268,
    "tx_hash": "th_26xCyuKpvs3CTUxTbycDXDQbYt2xQbd6Rf2uJEWSNDAyFSucNK",
    "tx_index": 17157444,
    "tx_type": "contract_call_tx"
  }
]
```

---

## Statistics

### `/v2/deltastats`

To show a statistics for a given height, we can use "stats" endpoint:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/deltastats?limit=1" | jq '.'
{
  "data": [
    {
      "active_auctions": 1249,
      "active_names": 1754,
      "active_oracles": 9,
      "block_reward": 97460926597753680000000000,
      "contracts": 1368,
      "dev_reward": 7359459527973738000000000,
      "height": 419208,
      "inactive_names": 538056,
      "inactive_oracles": 18
    }
  ],
  "next": "/v2/deltastats?scope=gen:419209-0&limit=1&cursor=419208"
}
```

### `/v2/totalstats`

Aggregated (sumarized) statistics are also available, showing the total sum of rewards and the token supply:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/totalstats?gen:421454-0&limit=1" | jq '.'
{
  "data": [
    {
      "height": 421453,
      "sum_block_reward": 2.575586328292814e+31,
      "sum_dev_reward": 1425114681800906500000000000000,
      "total_token_supply": 2.718122171075295e+31
    }
  ],
  "next": "/v2/totalstats?scope=gen:421454-0&limit=1&cursor=42152"
}
```

These endpoints allows pagination, with typical `forward/backward` direction or scope denoted by `gen/from-to`.

### `/v2/minerstats`

Total reward given to each chain miner.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/minerstats?limit=1" | jq '.'
{
  "data": [
    {
      "miner": "ak_2wkBCLxwjfcT3DHoisV7tGVQK8uni8XQwWZ6RUKD9DDwYSz8XN",
      "total_reward": 76626041292504000000
    }
  ],
  "next": "/v2/totalminers?cursor=ak_2wk52gAYRWAMi7gWP7A1oMvHEP9kpmp471VJFpvVzWMHnRc47a",
  "prev": null
}
```

## Migrating to v2

Most routes will remain the same, and can be updated by only appending the `/v2` prefix to them.

This is a list of the exceptions together with the changes that need to be done:

* `/blocks/:range_or_dir` - Can now be accessed via `/v2/blocks?scope=gen:100-200` or `/v2/blocks?direction=forward`. In addition, each block now has a list of micro_blocks sorted by time, instead of it being a map.
* `/blocki/:id` - Was renamed to `/v2/blocks/:id`.
* `/blocki/:kbi/:mbi` - Was renamed to `/v2/blocks/:kbi/:mbi`.
* `/name/auction/:id` - Was renamed to `/v2/names/:id/auction`.
* `/name/pointers/:id` - Was renamed to `/v2/names/:id/pointers`.
* `/name/pointees/:id` - Was renamed to `/v2/names/:id/pointees`.
* `/name/:id` - Was renamed to `/v2/names/:id`.
* `/names/owned_by/:id` - Can now be accessed via `/v2/names?owned_by=:id`, to filter by active a `state=active` or `state=inactive` additional parameter can be used.
* `/names/active` - Can now be accessed via `/v2/names?state=active`.
* `/names/inactive` - Can now be accessed via `/v2/names?state=inactive`.
* `/names/:scope_type/:range`, `/names/active/:scope_type/:range` and
  `/names/inactive/:scope_type/:range` - Can now be accessed via `/v2/names?scope=txi:100-200` or `/v2/names?scope=gen:30-40`.
* `/names/auctions` - Can now be accessed via `/v2/names/auctions`
* `/names/auctions/:scope_type/:range` - Can now be accessed via `/v2/auctions?scope=gen:10-100` (or `?scope=txi:1000-2000`).
* `/names/search/:prefix` - The prefix is no longer part of the path, but a query parameter instead (`?prefix=...`).
* `/oracles/:state/:scope_scope/:range`, `/oracles/:scope_scope/:range` - Can now all be accessed via `/v2/oracles?state=inactive&scope=gen:100-200`.
* `/contracts/logs/:direction`, `/contracts/logs/:scope_type/:range` - Can now be accessed via `/v2/contracts/logs?scope=txi:100-200` or `/v2/contracts/logs?scope=gen:30-40`.
* `/contracts/calls/:direction`, `/contracts/calls/:scope_type/:range` - Can now be accessed via `/v2/contracts/calls?scope=txi:100-200` or `/v2/contracts/calls?scope=gen:30-40`.
* `/aex9/by_name/:prefix` - Is now `/v2/aex9?by=name&prefix=<prefix>`, a paginated endpoint.
* `/aex9/by_symbol/:prefix` - Is now `/v2/aex9?by=symbol&prefix=<prefix>`, a paginated endpoint.
* `/aex9/by_contract/:id` - Is now `/v2/aex9/:contract_id`.
* `/aex9/balances/:contract_id` - Is now `/v2/aex9/:contract_id/balances`, a paginated endpoint.
* `/aex9/balance/:contract_id/:account_id` - Is now `/v2/aex9/:contract_id/balances/:account_id`.
* `/aex9/gen/:range/:contract_id` - Removed on v2.
* `/aex9/hash/:blockhash/:contract_id` - Removed on v2.
* `/aex9/balances/gen/:height/account/:account_id`, `/aex9/balances/hash/:blockhash/account/:account_id` - Is now `/v2/aex9/account-balances/:account_id?scope=gen:5000-6000`.
* `/aex9/balances/account/:account_id` - Is now `/v2/aex9/account-balances/:account_id?scope=gen:5000-6000`.
* `/transfers/:direction`, `/transfers/:scope_type/:range` - Can now be accessed via `/v2/transfers?scope=txi:100-200` or `/v2/transfers?scope=gen:30-40`.
* `/stats/:direction`, `/stats/:scope_type/:range` - Can now be accessed via `/v2/deltastats?direction=forward` or `/v2/deltastats?scope=gen:100-200`.
* `/totalstats/:direction`, `/totalstats/:scope_type/:range` - Can now be accessed via `/v2/totalstats?direction=forward` or `/v2/totalstats?scope=gen:100-200`.
* `/status` - Can now be accessed via `/v2/status`.

## Websocket interface

The websocket interface, which listens by default on port `4001`, gives asynchronous notifications when various events occur.
Each event is notified twice: firstly when the Node has synced the block or transaction and after when AeMdw indexation is done.
In order to differentiate, please check the "source" field on [Publishing Message format](#pub-message-format).

### Subscription Message format

```
{
"op": <subscription operation>,
"payload": "<message payload>",
}
```

### Supported subscription operations

  * Subscribe
  * Unsubscribe

### Supported payloads

  * KeyBlocks
  * MicroBlocks
  * Transactions
  * Object, which takes a further field, `target` - can be any æternity entity. So you may subscribe to any æternity object type, and be sent all transactions which reference the object. For instance, if you have an oracle `ok_JcUaMCu9FzTwonCZkFE5BXsgxueagub9fVzywuQRDiCogTzse` you may subscribe to this object and be notified of any events which relate to it - presumable you would be interested in queries, to which you would respond. Of course you can also subscribe to accounts, contracts, names, whatever you like.


The websocket interface accepts JSON - encoded commands to subscribe and unsubscribe, and answers these with the list of subscriptions. A session will look like this:

```
wscat -c wss://mainnet.aeternity.io/mdw/websocket

connected (press CTRL+C to quit)
> {"op":"Subscribe", "payload": "KeyBlocks"}
< ["KeyBlocks"]
> {"op":"Ping"}
< {"subscriptions":["KeyBlocks"],"payload":"Pong"}
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

### Publishing Message format

```
{
"payload": "<sync info payload>",
"source": "node" | "mdw",
"subscription": "KeyBlocks" | "MicroBlocks" | "Transactions" | "Object"
}
```

When the `source` is "node" it means that the Node is synching the block or transaction (not yet indexed by AeMdw).
If it's "mdw", it indicates that it's already avaiable through AeMdw Api.

## Tests

### Unit tests

Running unit tests will not sync the database. To run them:
```
elixir --sname aeternity@localhost -S mix test
```.

### Integration tests

The database has to be fully synced. Then, run the tests with:
```
elixir --sname aeternity@localhost -S mix test.integration
````.

## CI

#### Actions

On push:
- Commit linter for conventional commit messages
- Elixir code formatting
- Credo
- Dialyzer
- Unit tests
- ExCoveralls

On merge to master:
- Release with notes based on git history

#### Git hooks

In order to anticipate some of these checks one might run `mix git_hooks.install`.
This installs pre_commit and pre_push checks as defined by `config :git_hooks` in `dev.tools.exs`.

If sure about the change, if it was for example in a integration test case and it was already tested and formatted,
one can use `git push --no-verify` to bypass the hook.