# AeMdw - Aeternity Middleware

<!-- use emacs or npm markdown-toc with "markdown-toc --bullets=- README.md" -->
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [Database snapshot](#database-snapshot)
  - [Node Configuration](#node-configuration)
  - [Volumes Configuration](#volumes-configuration)
  - [Genesis accounts](#genesis-accounts)
  - [Docker setup for local dev](#docker-setup-for-local-dev)
  - [Tools for local development](#tools-for-local-development)
- [Hosted infrastructure](#hosted-infrastructure)
- [HTTP v3 (latest) endpoints](#http-v3-latest-endpoints)
- [OpenAPI specs](#openapi-specs)
- [Pagination](#pagination)
- [Additional endpoint options](#additional-endpoint-options)
- [Transactions](#transactions)
- [Blocks](#blocks)
- [Naming System](#naming-system)
- [Contracts](#contracts)
- [Internal transfers](#internal-transfers)
- [Oracles](#oracles)
- [Channels](#channels)
- [AEX9 tokens](#aex9-tokens)
- [AEX9 contract balances](#aex9-contract-balances)
- [NFTs](#aex141)
- [Statistics](#statistics)
- [Activities](#activities)
- [Websocket interface](#websocket-interface)
- [Tests](#tests)
- [Auto-generated Documentation](#auto-generated-documentation)

<!-- markdown-toc end -->


## Overview

The middleware is a caching and reporting layer which sits in front of the nodes of the [æternity blockchain](https://github.com/aeternity/aeternity). Its purpose is to respond to queries faster than the node can do, and to support queries that for reasons of efficiency the node cannot or will not support itself.

The architecture of the app is explained [here](docs/architecture.md).


## Setup

Firstly, clone the middleware repo:

`git clone https://github.com/aeternity/ae_mdw && cd ae_mdw`

Before running it, it's recommended to use a Node database snapshot for faster syncing.

### Database Snapshot

1. Download one of the full backups from https://downloads.aeternity.io
2. Create a 'data' directory under the root repo dir and extract the backup to it (it creates a mnesia directory).

To start a docker container on mainnet, simply run: `docker-compose up`.

You can check on `/status` page that the `node_height` is higher than 600000.

In case you want to use it on testnet or for development purposes please follow the instructions below.

### Node configuration

The middleware runs along with an Aeternity Node on the same docker container and BEAM VM instance.

Its configuration file is found at `docker/aeternity.yaml`. Under `fork_management` key, the `network_id` options are: `ae_mainnet` and `ae_uat` (testnet).

If you are running your own build, on dev environment, with `docker-compose-dev.yml` the `docker/aeternity.yaml` is copied when the container is started and it is used as a node configuration file.

For docker hub images, you can create a volume to copy your local `/home/aeternity/aeternity.yaml` by uncommenting it on `docker-compose.yml`.

You may also redefine other Aeternity node configurations. More information regarding configuration can be found [here](https://docs.aeternity.io/en/stable/configuration/)

### Volumes configuration

The `aeternity/ae_mdw` docker image runs with unprivileged user (uid=1000).

Therefore permissions should be given when mapping the `data/mnesia` and/or `data/mdw.db` volumes:
```
mkdir -p data/mnesia data/mdw.db
chown -R 1000 data
```

### Genesis accounts

In case you want to setup different accounts on testnet with initial balance you can add this volume to `docker-compose-dev.yml`:

`- ${PWD}/accounts_test.json:/home/aeternity/node/local/rel/aeternity/data/aecore/.genesis/accounts_test.json`

An example of `accounts_test.json` is:

```
{
   "ak_2a1j2Mk9YSmC1gioUq4PWRm3bsv887MbuRVwyv4KaUGoR1eiKi": 10000000000000000000000000000000
}
```

### Docker setup for local dev

The project comes with a two docker compose files:

  * `docker-compose.yml`: to run the middleware as is
  * `docker-compose-dev.yml`: for development env that includes dev tools

A helper script might be used to get a docker shell on dev env: `./scripts/do.sh docker-shell`

You should now be able to navigate through the project having the `/app` as working directory.

### Tools for local development

When inside the docker container shell, some useful commands that you might want to run are:

```
iex --sname aeternity@localhost -S mix                                        # IEx shell
elixir --sname aeternity@localhost -S mix phx.server                          # Start the server
elixir --sname aeternity@localhost -S mix test                                # Unit tests
INTEGRATION_TEST=1 elixir --sname aeternity@localhost -S mix test.integration # Integration tests
mix format                                                                    # Run formatting tool
mix credo                                                                     # Run `credo` tool
mix dialyzer                                                                  # Run `dialyzer` tool
```

## Hosted Infrastructure

We currently provide hosted infrastructure at https://mainnet.aeternity.io/mdw/ , all examples here are based on it.

**NOTE:** Local deploy with default configuration endpoints **will not** contain `/mdw/` segment on the path.

## HTTP v3 (latest) endpoints

The routes and respective responses are:

```
GET /v3/key-blocks                           - key blocks with micro blocks and transaction counts
GET /v3/key-blocks/:hash_or_kbi              - key block by hash or height
GET /v3/key-blocks/:hash_or_kbi/micro-blocks - micro block belonging to key block
GET /v3/micro-blocks/:hash                   - micro block with transaction count
GET /v3/micro-blocks/:hash/transactions      - micro block transactions

GET /v3/transactions                            - transactions in any direction
GET /v3/transactions/:hash                      - transaction by hash
GET /v3/transactions/count                      - total number of transactions (last transaction index + 1)

GET /v3/accounts/:id/activities             - transactions, internal contract calls, AEX-N and internal transfers involving an account
GET /v3/accounts/:account_id/aex9/balances  - aex9 account balances
GET /v3/accounts/:account_id/names/pointees - AENS names that point to the account

GET /v3/contracts                         - contracts
GET /v3/contracts/:id                     - contract by id
GET /v3/contracts/logs                    - contract logs
GET /v3/contracts/calls                   - contract calls

GET /v3/names                              - AENS names
GET /v3/names/:id/auction                  - AENS name auction
GET /v3/names/:id/pointers                 - AENS name pointer
GET /v3/names/auctions                     - all AENS name auctions
GET /v3/names/:id                          - AENS name state and transaction history
GET /v3/names/:id/claims                   - AENS name claims history
GET /v3/names/:id/updates                  - AENS name update history
GET /v3/names/:id/transfers                - AENS name transfer history

GET /v3/oracles                         - expired oracles ordered by expiration height, filtered by active/inactive state and scope
GET /v3/oracles/:id                     - oracle information by hash
GET /v3/oracles/:id/queries             - oracle queries
GET /v3/oracles/:id/responses           - oracle responses

GET /v3/channels                        - active channels ordered by activation height
GET /v3/channels/:id                    - active or inactive channel
GET /v3/channels/:id/updates            - displays all updates done to a channel

GET /v3/transfers                        - internal transfers from the top of the chain

GET /v3/aex9                                           - aex9 contracts
GET /v3/aex9/:contract_id                              - aex9 contract tokens
GET /v3/aex9/:contract_id/balances                     - aex9 contract balances
GET /v3/aex9/:contract_id/balances/:account_id         - aex9 contract account balance
GET /v3/aex9/transfers                                 - aex9 transfers that can be filtered by sender/recipient
GET /v3/aex9/:contract_id/balances/:account_id/history - aex9 contract account balanances history

GET /v3/aex141                                         - nft contracts meta info and stats
GET /v3/aex141/:contract_id                            - nft contract meta info and stats
GET /v3/aex141/owned-nfts/:account_id                  - nfts owned by a wallet
GET /v3/aex141/:contract_id/owner/:token_id            - the owner wallet address of a NFT
GET /v3/aex141/:contract_id/owners                     - the owners wallets of NFTs from a collection
GET /v3/aex141/:contract_id/templates                  - nft templates
GET /v3/aex141/:contract_id/templates/:id/tokens       - nft supply from a template
GET /v3/aex141/transfers                               - nft transfers that can be filtered by sender/recipient

GET /v3/deltastats                       - statistics for generations from tip of the chain
GET /v3/totalstats                       - aggregated statistics for generations from tip of the chain
GET /v3/minerstats                       - total rewards for each miner

GET /v3/statistics/transactions                - statistics over time of transactions count
GET /v3/statistics/blocks                      - statistics over time of blocks count
GET /v3/statistics/names                       - statistics over time of names count

GET /v3/status                           - middleware status
```

## OpenAPI specs

The swagger specification of the endpoints can be downloaded from:

- https://testnet.aeternity.io/mdw/v3/api/

It can be visualized on a swagger UI at:

- https://testnet.aeternity.io/mdw/swagger

This npm package can be also used for a self-hosted app to visualize these specs:
https://www.npmjs.com/package/swagger-ui

## Pagination

The application does not support paginated page-based endpoints. Instead, a
cursor-based pagination is offered. This means that in order to traverse through
a list of pages for any of the paginated endpoints, either the `next` or `prev`
field from the current page has to be used instead.

Asking for an arbitrary page, without first retrieving it from the `next` or
`prev` field **is not supported**.

The paginated endpoints return JSON in the following format:

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
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&limit=1" | jq '.'
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
  "next": "/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779354&limit=1",
  "prev": "/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=19813844&limit=1&rev=1"
}
```

Getting the next transaction by prepending host (https://mainnet.aeternity.io/mdw) to the continuation-URL from last request:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779354&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1779356&limit=1",
  "prev": "/v3/transactions?direction=backward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&cursor=1776073&limit=1&rev=1"
}
```

Once there are no more transactions for a query, the `next` and/or `prev` key is set to `null`.

### Limit

The client can set `limit` explicitly if he wishes to receive different number
of transactions in the reply than `10` (max `100`).

### Scope

The `scope` parameter specifies the time period to look for results matching the criteria:

- `gen:A-B`   - from generation A to B (forward if A < B, backward otherwise)

Not all paginated endpoints support all scopes.

### Direction

All paginated endpoints support a `direction` parameter that specifies the order in which results are expected to be returned.

It can be either `forward` or `backward` (default).

## Additional endpoint options

In many of the endpoints there's some additional query parameters that can be sent to change the endpoint behavior.

### `top`

When `top=true`, it displays the latest state of the changes by querying the node directly. This is allowed on some of the `AEx9` endpoints to obtain the latest balances state for a given contract.

### `int-as-string`

If this flag is set to `true`, the response will have all integers set as strings

----

## Transactions

### `/v3/transactions`

Querying for transactions via `/v3/transactions` endpoint supports 3 kinds of parameters specifying which transactions should be part of the reply:

- types
- generic ids
- transaction fields

#### Types

Types of transactions in the resulting set can be constrained by providing `type` and/or `type_group` parameter.
The query allows providing of multiple type & type_group parameters - they form a union of admissible types.
(In other words - they are combined with `OR`.)

Supported types:

* `channel_close_mutual`, `channel_close_solo`, `channel_create`, `channel_deposit`, `channel_force_progress`, `channel_offchain`, `channel_settle`, `channel_slash`, `channel_snapshot_solo`, `channel_withdraw`.
* `contract_call`, `contract_create`
* `ga_attach`, `ga_meta`
* `name_claim`, `name_preclaim`, `name_revoke`, `name_transfer`, `name_update`
* `oracle_extend`, `oracle_query`, `oracle_register`, `oracle_response`
* `paying_for`
* `spend`

Supported type groups:

* `channel`
* `contract`
* `ga`
* `name`
* `oracle`
* `paying`
* `spend`

Examples:

`type` parameter:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&type=channel_create&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&cursor=73270&limit=1&type=channel_create"
  "prev": null
}
```

`type_group` parameter:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&type_group=oracle&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&cursor=8892&limit=1&type_group=oracle",
  "prev": null
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

Examples

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2" | jq '.'
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
      }
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=8401663&limit=2",
  "prev": null
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&cursor=600286&limit=1&oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
  "prev": null
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&limit=2" | jq '.'
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
      }
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&channel=ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD&cursor=94617&limit=2",
  "prev": null
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
- entrypoint - contract_call
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
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&limit=1" | jq '.'
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
  "next": "/v3/transactions?direction=forward&cursor=11734834&limit=1&name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF"
}
```

freestanding field `from_id`, and via `jq` extracting only hash and transaction type:

```
curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?from_id=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&limit=5" | jq '.data | .[] | [.hash, .tx.type]'
[
  "th_s1C1VC1nwWR4WB8qqJ7o9VokTTPQkAmKQ4aEfQf2GnVa4GKqw",
  "ChannelForceProgressTx"
]
[
  "th_2donST82cDa4trBqE4d2m7kPoTe56cvQVZ52aSoNG8V4UnV8vX",
  "ChannelSettleTx"
]
[
  "th_2wevgEPtCdRMpPaoHRQjyaApXK9FbErnM3UtqN7KDmbxjEeiAQ",
  "ChannelSlashTx"
]
[
  "th_YcFkm7qTgEe5zFhCB21td6f68u1WTH8qArZZwsNqhJCSzhJ3L",
  "ChannelSnapshotSoloTx"
]
[
  "th_qT9SvwhKZaUeVJLvr4e24gBYCwXaszdMPgRAZismKK2oecFAi",
  "ChannelDepositTx"
]
```

#### Mixing of query parameters

The query string can mix types, global ids and transaction fields.

The resulting set of transactions must meet all constraints specified by parameters denoting ID (global ids and transaction fields) - the parameters are combined with `AND`.

If `type` or `type_group` is provided, the transaction in the result set must be of some type specified by these parameters.

#### Examples

transactions where each transaction contains both accounts, no matter in which field:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?account=ak_zUQikTiUMNxfKwuAfQVMPkaxdPsXP8uAxnfn6TkZKZCtmRcUD&cursor=17022424&limit=1",
  "prev": null
}
```

spend transactions between sender and recipient (transaction type = spend is deduced from the fields):
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&limit=1" | jq '.'
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
      }
    }
  ],
  "next": "/v3/transactions?direction=forward&cursor=41&limit=1&recipient_id=ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2&sender_id=ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
  "prev": null
}
```

name related transactions for account:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions?direction=forward&account=ak_E64bTuWTVj9Hu5EQSgyTGZp27diFKohTQWw3AYnmgVSWCnfnD&type_group=name" | jq '.'
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
      }
    }
  ],
  "next": null,
  "prev": null
}
```

### `/v3/transactions/:hash`

Single transactions can be obtained by either the identifying hash or transaction index.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions/th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq" | jq '.'
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
  }
}
```

### `/txs/count`

Counting all transactions

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions/count" | jq '.'
11921825
```

It can also be scoped by generations:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions/count?scope=gen:123-456" | jq '.'
23
```

Or by address:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions/count?id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR" | jq '.'
19323
```

Or by type:
```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transactions/count?tx_type=oracle_register" | jq '.'
286
```

**NOTE**: It cannot be filtered by more than one of these filters.

---

## Blocks

### `/v3//key-blocks`

There are several endpoints for querying block(s) or generation(s). A generation can be understood as key block and micro blocks containing transactions.

Since we are returning whole generations, replies can be very large.

Examples below are trimmed heavily.

With /v3/key-blocks endpoint:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/key-blocks?scope=gen:101125-101125" | jq '.'
{
  "data": [
    {
      "beneficiary" : "ak_2MR38Zf355m6JtP13T3WEcUcSLVLCxjGvjk6zG95S2mfKohcSS",
      "hash" : "kh_2MK98WvTtAMzvNNJSi62iConXWshwDM49pfyQi2uVPXE73vv7p",
      "height" : 101125,
      "info" : "cb_AAAAAfy4hFE=",
      "micro_blocks_count" : 1,
      "miner" : "ak_2HToRDUsCuBqdGsFqCCE19chrRQ7hhYE5Ebd3LETfwnk3gGnzX",
      "nonce" : 9256408633249849368,
      "pow" : [5377241, ..., 514753955],
      "prev_hash" : "kh_tPiapdedaKhT8egWrtLWsvACbEzTbpECdWg9P8dTtK8P8w48s",
      "prev_key_hash" : "kh_tPiapdedaKhT8egWrtLWsvACbEzTbpECdWg9P8dTtK8P8w48s",
      "state_hash" : "bs_2SF46f1xU4uxiKKVmeT9jqFWJenftFzXTVse9GGLwtit78zHQP",
      "target" : 504458445,
      "time" : 1561595666398,
      "transactions_count" : 4,
      "version" : 3
    }
  ],
  "next": null,
  "prev": null
}
```

Numeric range:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/key-blocks?scope=gen:100000-100100&limit=3" | jq '.'
{
  "data": [
    {
      "beneficiary" : "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash" : "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
      "height" : 100000,
      "info" : "cb_AAAAAfy4hFE=",
      "micro_blocks_count" : 1,
      "miner" : "ak_2K5fAjna26t2U2V6v2LwNBUZpT9puriPdvxifDmGRoqG1a7R3Z",
      "nonce" : 14620604494251230255,
      "pow" : [8664748, ..., 485310990],
      "prev_hash" : "mh_2EFE1CxvXM2dKtu4Jt4yLAbW8gS5MkpDtNmGKHP4bPXDvtubKJ",
      "prev_key_hash" : "kh_B18SQZmResYV5yqxbFUizKPqrtrjky3LESGUvRECDp9N2kNmA",
      "state_hash" : "bs_185cZMdvy6wJXjCZDwGnLJ4TCrU18yxGSVkbtQh4DyCm2yPaV",
      "target" : 504047608,
      "time" : 1561390154570,
      "transactions_count" : 1,
      "version" : 3
    },
    {
      "beneficiary" : "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash" : "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
      "height" : 100001,
      "info" : "cb_AAAAAfy4hFE=",
      "micro_blocks_count" : 2,
      "miner" : "ak_2AT33FPB7DSvd3XU2nKPh4sUbBjb6jHWtKh6CF2b1eK2y3daA3",
      "nonce" : 8862664339569827477,
      "pow" : [7438320, ..., 519071892],
      "prev_hash" : "mh_zpiiJYsHZZ9ibKSF1fGLcossdgFjHNaN2Yu6cEF9KSNLqQLbS",
      "prev_key_hash" : "kh_foi6pMgz1zi17tYy5eBMQMzCLf7jaAYQTL9WtoJiqR5bk38hg",
      "state_hash" : "bs_Wqv4So3wfCV2eyJMnjfiGsrb1D7nrUk2r6K9ufgnX22J5wVPA",
      "target" : 504063592,
      "time" : 1561390309740,
      "transactions_count" : 2,
      "version" : 3
    },
    {
      "beneficiary" : "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "hash" : "kh_2BXy8tftXFVj859j4YpkTyf7Ld5AXrvPqUSbYwGoWZpKQ9VNVB",
      "height" : 100002,
      "info" : "cb_AAAAAfy4hFE=",
      "micro_blocks_count" : 1,
      "miner" : "ak_2VJtWGt45q8w9Aj7gYJPz9kZG3EU45xi6YZ4wgXSb25MeYGdfM",
      "nonce" : 5829762670850390403,
      "pow" : [1917903, ..., 530252456],
      "prev_hash" : "mh_NxwB3r43rT4ghZscfuXhHNKNouuVQmU1Lkrf4sgCTPYy3Szdr",
      "prev_key_hash" : "kh_2gJqm1zmvpMGLMiViwwiHE2EhvdzWjm6KBVthRouHM71rCnUuN",
      "state_hash" : "bs_2E75ChNX5EZo42xek6K64i5MZfQNxDUo5M9DwAufFRqQRqx3Z5",
      "target" : 504062474,
      "time" : 1561390340812,
      "transactions_count" : 1,
      "version" : 3
    }
  ],
  "next" : "/v3/key-blocks?cursor=100003&limit=3&scope=gen%3A100000-100100",
  "prev" : null
}
```

### `/v3/key-blocks/:hash_or_kbi`

Retrieves a single key block including the `micro_blocks_count` and `transactions_count` counters.

```
$ curl -s https://mainnet.aeternity.io/mdw/v3/key-blocks/kh_2oKCXoTcm7rSxxAHaEcoUe6JV7Xs9Nmk3TNXHSEQcs9NwE8o6W
{
  "micro_blocks_count": 204,
  "transactions_count": 273,
  "beneficiary": "ak_wM8yFU8eSETXU7VSN48HMDmevGoCMiuveQZgkPuRn1nTiRqyv",
  "hash": "kh_2oKCXoTcm7rSxxAHaEcoUe6JV7Xs9Nmk3TNXHSEQcs9NwE8o6W",
  "height": 653413,
  "info": "cb_AAACjBq0Xcc=",
  "miner": "ak_2XTwJ1uqopnb6swmNCA35AuzgZJ8cqJqT1jtGi1j3pKzrsnXGL",
  "nonce": 11146303448381,
  "pow": [
    470518102,
    470786769,
    472378123,
    477583630,
    477907327,
    488321757,
    491143869,
    493744235,
    505396477,
    518355451,
    531366816
  ],
  "prev_hash": "mh_StyRqEViVt5z4pvFu6LeJXjy3eh9He7w83UUPsp2gfxnHMrqb",
  "prev_key_hash": "kh_2mkrqWnKFBhEdX5B27pmvd1LN6FqQfHm2XzXo2uc5ZGAqkrwRf",
  "state_hash": "bs_2pgQNoRYU32wCv3ESvHg6RYpSgsXX9NjkKJ2TuaZnxW6qqVtsN",
  "target": 520136850,
  "time": 1662676277823,
  "version": 5
}
```

Or alternatively, by `kbi`:

```
$ curl -s https://mainnet.aeternity.io/mdw/v3/key-blocks/123
{
  "micro_blocks_count": 0,
  "transactions_count": 0,
  "beneficiary": "ak_TFm6MPeRXz4oiy5rQ9QRsFpaQb27GCc5ZEXCDhCFPYvYWxV5v",
  "hash": "kh_c1F1ZfcqhLMqPNoTzgNKAp3n18kPMCrWvuH9j2Dc2kdiUteRZ",
  "height": 123,
  "info": "cb_Xfbg4g==",
  "miner": "ak_2W4cmcpJQZ4JeBF1kPoe5UsEZCS4gzbCWtoDsVDr7EzF65bmkf",
  "nonce": 2384355247607917600,
  "pow": [
    28236516,
    37891637,
    39568937,
    41751636,
    53905843,
    77440491,
    77746610,
    80023552,
    85642112,
    89247851,
    105135109
  ],
  "prev_hash": "kh_MD6dBz1sk6n4P4HZUjzwfiLHSMxzmFk5ZVjcG5cF7PqBCgT9b",
  "prev_key_hash": "kh_MD6dBz1sk6n4P4HZUjzwfiLHSMxzmFk5ZVjcG5cF7PqBCgT9b",
  "state_hash": "bs_2pAUexcNWE9HFruXUugY28yfUifWDh449JK1dDgdeMix5uk8Q",
  "target": 521613269,
  "time": 1543395219643,
  "version": 1
}
```

### `/v3/key-blocks`

Returns a paginated list of key-blocks together with the amount of micro blocks and transactions each key-block generation has.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/key-blocks?limit=1" | jq '.'
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
  "next": "/v3/key-blocks?cursor=652729&limit=1",
  "prev": null
}
```

### `/v3/key-blocks/:hash_or_kbi/micro-blocks`

```
$ curl https://mainnet.aeternity.io/v3/key-blocks/kh_2HvzkfTvRjfwbim8YZ2q2ETKLhuYK125JGpisr1Cc9m2VSa5iC/micro-blocks?limit=1
{
  "data": [
    {
      "micro_block_index": 39,
      "transactions_count": 0,
      "hash": "mh_HqJKqWdJ1vaPcr82zYNue99GXcKfjpYbmrEcZ7kmUHAzQoeZv",
      "height": 654915,
      "pof_hash": "no_fraud",
      "prev_hash": "mh_G2gtKvDAkoi3HZDe5TmWYzGX2pD2AL2DrFXACTch57QEWi1Bo",
      "prev_key_hash": "kh_2HvzkfTvRjfwbim8YZ2q2ETKLhuYK125JGpisr1Cc9m2VSa5iC",
      "signature": "sg_Eyv2nWKwMbxga4XDHH2oCtnSCWhtD87qUjvFLqKvzt9kq2yVPMkcHSv51kr9fmHQk6TGxBHjRjm74pVZtNuHpZkvybsXX",
      "state_hash": "bs_2WNN8aZ15a7pd68wWDZkTqpGUTPezUV6KTN2ra5m3v1x5vVJGC",
      "time": 1662950429203,
      "txs_hash": "bx_AK5hwnJdG3KAEHEvzs4gwjkRDZP5sw5sbtqgHsgJT2fp1PJka",
      "version": 5
    }
  ],
  "next": "/v3/key-blocks/kh_2HvzkfTvRjfwbim8YZ2q2ETKLhuYK125JGpisr1Cc9m2VSa5iC/micro-blocks?cursor=38&limit=1",
  "prev": null
}
```

### `/v3/micro-blocks/:hash`

```
$ curl https://mainnet.aeternity.io/mdw/v3/micro-blocks/mh_HqJKqWdJ1vaPcr82zYNue99GXcKfjpYbmrEcZ7kmUHAzQoeZv
{
  "micro_block_index": 39,
  "transactions_count": 0,
  "hash": "mh_HqJKqWdJ1vaPcr82zYNue99GXcKfjpYbmrEcZ7kmUHAzQoeZv",
  "height": 654915,
  "pof_hash": "no_fraud",
  "prev_hash": "mh_G2gtKvDAkoi3HZDe5TmWYzGX2pD2AL2DrFXACTch57QEWi1Bo",
  "prev_key_hash": "kh_2HvzkfTvRjfwbim8YZ2q2ETKLhuYK125JGpisr1Cc9m2VSa5iC",
  "signature": "sg_Eyv2nWKwMbxga4XDHH2oCtnSCWhtD87qUjvFLqKvzt9kq2yVPMkcHSv51kr9fmHQk6TGxBHjRjm74pVZtNuHpZkvybsXX",
  "state_hash": "bs_2WNN8aZ15a7pd68wWDZkTqpGUTPezUV6KTN2ra5m3v1x5vVJGC",
  "time": 1662950429203,
  "txs_hash": "bx_AK5hwnJdG3KAEHEvzs4gwjkRDZP5sw5sbtqgHsgJT2fp1PJka",
  "version": 5
}
```

### `/v3/micro-blocks/:hash/txs`

```
$ curl https://mainnet.aeternity.io/mdw/v3/micro-blocks/mh_3TzzPsMhgnJBYAtSJ6c4SdbQppZi64mxP61b1u1E8g3stDQwk/txs?limit=1
{
  "data": [
    {
      "block_hash": "mh_3TzzPsMhgnJBYAtSJ6c4SdbQppZi64mxP61b1u1E8g3stDQwk",
      "block_height": 14085,
      "hash": "th_2Eo84A8gYkaNnRXkkEe9gPg5jcbKGdPVkZvK9XUSEQhDD6kmqm",
      "micro_index": 59,
      "micro_time": 1545877257605,
      "signatures": [
        "sg_E6tbrssPGL4a1mXyN5EW9d3UwRfYN9pSsBDtDEQVyQqTQjhQVBPKNJV6qyc43M5zY2tLE8VQa8Jb3q1XGYKJYaHM5Q3T4"
      ],
      "tx": {
        "amount": 43734300000000000000,
        "fee": 21000,
        "nonce": 19631,
        "payload": "ba_SGVsbG8sIE1pbmVyISAvWW91cnMgQmVlcG9vbC4vKXcQag==",
        "recipient_id": "ak_2gD9eHc6AaLSgUKne5vVLrsnG4acTCDE7KPetE4PqA8MYvz8gN",
        "sender_id": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
        "type": "SpendTx",
        "version": 1
      }
    }
  ],
  "next": null,
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

Using `transactions/:hash` endpoint is flexible, on-demand way to get detailed transaction information, but in some situations leads to multiple round trips to the server.

Due to this reason, all name endpoints except `name/pointers` and `name/pointees` support `expand` parameter (either set to `true` or without value), which will replace the transaction indices with the JSON body of the transaction detail.

### `/v3/names`

Names can be filtered by state, which can contain the following values:

- `inactive` - for listing `inactive` names (expired or revoked)
- `active` - for listing `active` names
- `auction` - for listing `auctions`

They support ordering via parameters `by` (with value `activation`, `deactivation` or `name`).

Using the `by=activation` requires `state=active` and includes only successfully claimed names (those in auction won't appear yet).

Using the `by=deactivation` means for inactive names that they are sorted by the height of deactivation, whether the name had expired or had been revoked.
For active names it means they are sorted by expiration height.

Without these parameters, the endpoints return results ordered as if `by=deactivation` were provided.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "hash": "nm_qock4y2xnYdyy779vayFfu7YUBTwy9bTfoJeH4pM5EpRyJU3A",
      "active_from": 205194,
      "auction_timeout": 14880,
      "expire_height": 349080,
      "ownership": {
        "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
        "original": "ak_pMwUuWtqDoPxVtyAmWT45JvbCF2pGTmbCMB4U5yQHi37XF9is"
      },
      "pointers": {
        "account_pubkey": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
      },
      "revoke": null,
      "auction": null,
      "name": "jieyi.chain"
    },
    {
      "active": true,
      "hash": "nm_8vYbsvsrBow6jpxPHUtMLKG6EfTKqqwfpu425aJuHKafSxyR6",
      "active_from": 253179,
      "auction_timeout": 480,
      "expire_height": 349071,
      "ownership": {
        "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
        "original": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx"
      },
      "pointers": {
        "account_pubkey": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
      },
      "revoke": null,
      "auction": null,
      "name": "helloword.chain"
    }
  ],
  "next": "/v3/names?by=deactivation&cursor=703645-jiangjiajia.chain&limit=2",
  "prev": null
}
```

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?state=inactive&by=deactivation&direction=forward&limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "hash": "nm_PstDX8VxoTutPJG8YrXkWEwAfBoC5ZmoW1j5RZSNNyXa5oJSB",
      "active_from": 6089,
      "auction_timeout": 0,
      "expire_height": 16090,
      "ownership": {
        "current": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7",
        "original": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
      },
      "pointers": {
        "account_pubkey": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
      },
      "revoke": null,
      "auction": null,
      "name": "philippsdk.test"
    },
    {
      "active": false,
      "hash": "nm_J9wKEZ1Deo4UAnNo5s5VTRccVCLdZexZBQJgA6YHYy67xDpqy",
      "active_from": 6094,
      "auction_timeout": 0,
      "expire_height": 16094,
      "ownership": {
        "current": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7",
        "original": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
      },
      "pointers": {
        "account_pubkey": "ak_c3LfYDjLqdNdWHUCV8NDv1BELhXqfKxhmKfzh4cBMpwj64CD7"
      },
      "revoke": null,
      "auction": null,
      "name": "philippsdk2.test"
    }
  ],
  "next": "/v3/names?state=inactive&cursor=16117-philippsdk1.test&direction=forward&limit=2",
  "prev": null
}
```

Active names

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?state=active&by=name&limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "hash": "nm_23NKMgfB5igtdWHkY5BPMg75PykVrBTBpPAsE6Y1mYV3kZ8Nbd",
      "active_from": 162213,
      "auction_timeout": 0,
      "expire_height": 309542,
      "ownership": {
        "current": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8",
        "original": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8"
      },
      "pointers": {
        "account_pubkey": "ak_2tACpi3fVoP5kGo7aXw4riDNwifU2UR3AxxKzTs7FiCPi4iBa8"
      },
      "revoke": null,
      "auction": null,
      "name": "0000000000000.chain"
    },
    {
      "active": true,
      "hash": "nm_2q5bUSTcibKsuRfGnXSFC5JkUSUxiy9UbMuQ2uJn2xiYNZdcbL",
      "active_from": 183423,
      "auction_timeout": 480,
      "expire_height": 336933,
      "ownership": {
        "current": "ak_id5HJww6GzFBuFeVGX1NNM66fuzuyfvnCQgZmRxzdSnW8WRcv",
        "original": "ak_id5HJww6GzFBuFeVGX1NNM66fuzuyfvnCQgZmRxzdSnW8WRcv"
      },
      "pointers": {
        "account_pubkey": "ak_VLkEyJBmvaf6XnqLdknjj7ZMN58G5x1eJhNUkLxPFGmg9JAaJ"
      },
      "revoke": null,
      "auction": null,
      "name": "0123456789.chain"
    }
  ],
  "next": "/v3/names?state=active&cursor=zz.chain&limit=2",
  "prev": null
}
```

Additionally, this endpoint allows you to filter by name owner using the query param `owned_by`:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?owned_by=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN&by=name" | jq '.'
{
  "data": [
    {
      "active": false,
      "name": "yedianzhiwang.chain",
      "hash": "nm_2akgyVeSqDeynUVTHnHzengLarQyQqC9sHigsrBKnaCtmd3Ca5",
      "name_fee": 1771100000000000000,
      "revoke": null,
      "expire_height": 364002,
      "auction_timeout": 0,
      "auction": null,
      "ownership": {
        "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
        "original": "ak_2pqYSBpEkykFy11KFZXxDJaB8KugXBi2JxraqZXpTaXzreYb95"
      },
      "active_from": 163855,
      "approximate_expire_time": 1609161570008,
      "approximate_activation_time": 1572935113556
    }
  ],
  "next": null,
  "prev": null
}
```

An example of `by` usage:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?state=active&by=activation&direction=forward&limit=2" | jq '.'
{
  "data": [
    {
      "active": true,
      "auction": null,
      "hash": "nm_2FvtAFr3gPAQtNutEnjcPDQSqbhxDHBg9j8LE5WESPCJjzFmuU",
      "active_from": 161313,
      "auction_timeout": 0,
      "expire_height": 653635,
      "ownership": {
        "current": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV",
        "original": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV"
      },
      "pointers": {
        "account_pubkey": "ak_2QGAAqDXK7g8zCbck7zm25TGAW1hRuVCET2SRCCFCMSMjrVCrF"
      },
      "revoke": null,
      "name": "batchpayments.chain"
    },
    {
      "active": true,
      "auction": null,
      "hash": "nm_E5JeB8xLS9UR5qN65kDuAhRCHDno5B9pLwoXCm5DEKVpmWrUN",
      "active_from": 161349,
      "auction_timeout": 0,
      "expire_height": 653635,
      "ownership": {
        "current": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV",
        "original": "ak_5z1fmzTKR1GA1P7qiLDCC1s3V7AK2RRpNbXqUhfHQbUeg7mmV"
      },
      "pointers": {
        "account_pubkey": "ak_2QGAAqDXK7g8zCbck7zm25TGAW1hRuVCET2SRCCFCMSMjrVCrF"
      },
      "revoke": null,
      "name": "internetofmoney.chain"
    }
  ],
  "next": "/v3/names?by=activation&cursor=161350-internetofvalue.chain&direction=forward&limit=2&state=active",
  "prev": null
}
```

Names can also be filtered by prefix, as long as they are NOT filtered by owner and ordered by name (e.g. `?prefix=somenam&by=name`).

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names?prefix=aaa&by=name&limit=2" | jq '.'
{
  "data": [
    {
      "active": false,
      "name": "aaaz.test",
      "hash": "nm_28ZLaroYYUQ1B5MDa7FiKz2F7mSvrtPXSEfavbqXbg2y1ia28j",
      "revoke": null,
      "name_fee": 134626900000000000000,
      "auction_timeout": 0,
      "pointers": {},
      "auction": null,
      "expire_height": 130718,
      "active_from": 80718,
      "approximate_activation_time": 1557907284835,
      "approximate_expire_time": 1566948271337,
      "ownership": {
        "current": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
        "original": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf"
      }
    },
    {
      "active": false,
      "name": "aaay.test",
      "hash": "nm_2CtkYRVTtqnK6rf9Tc7AyyiHtcTFaustEzRLArAMiWUzXdAhTT",
      "revoke": null,
      "name_fee": 134626900000000000000,
      "auction_timeout": 0,
      "pointers": {},
      "auction": null,
      "expire_height": 130714,
      "active_from": 80714,
      "approximate_activation_time": 1557906623769,
      "approximate_expire_time": 1566948022162,
      "ownership": {
        "current": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf",
        "original": "ak_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf"
      }
    }
  ],
  "next": "/v3/names?by=name&cursor=aaaq.test&prefix=aaa",
  "prev": null
}
```

### `/v3/names/auctions`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/auctions?limit=2" | jq '.'
{
  "data": [
    {
      "name": "meta.chain",
      "name_fee": 134626900000000000000,
      "auction_end": 968903,
      "last_bid": {
        "block_hash": "mh_2F3vhNXJ1eXaQiAz6RQHzAUW5dEUTSEvxaBAHDn8ziHjrd9FJK",
        "block_height": 939143,
        "encoded_tx": "tx_+JYLAfhCuECFZmpTCOnm3v0zZ3g2BVIZApsjxGt4Q4MWck+gEw0j09Jq61XEgQWafn3fP2oesqcsy6wYGpGWT6eFW/iE7IoCuE74TCACoQH7BL4bl7Y/NrliWEMKWaxk9besmKUYp6PkFk7ZZeieHYIyZ4ptZXRhLmNoYWluhwUXe6y8hW+JB0xS1EQgCUAAhg8PrOrgAADImXsf",
        "hash": "th_2KpsBbibCN4EwtKNtLLAZzRw3AJ7xMEQw5sfbNZjQKCdP5pc5V",
        "micro_index": 0,
        "micro_time": 1714619449351,
        "signatures": [
          "sg_JTFJFCMh84NB9rJiHgzVcCgXsSt5i6njT4E55vLDRVoeXKuB4ETqzt1BB6TtAUrbGoGMYd4iXM7xuwPXXgVoWCPPZu8SS"
        ],
        "tx": {
          "account_id": "ak_2uYw22W3KGCCduExjzkBDNUxWt3Akdehm66CFAXDKRt9aoUofX",
          "fee": 16560000000000,
          "name": "meta.chain",
          "name_fee": 134626900000000000000,
          "name_id": "nm_2ab7LiFhV5uAzXq6EHmMsPm2cHoKaLdFMnwoTrkVaHSUAAZmx5",
          "name_salt": 1433194830005615,
          "nonce": 12903,
          "ttl": 1148903,
          "type": "NameClaimTx",
          "version": 2
        }
      },
      "approximate_expire_time": 1719979602317,
      "activation_time": 1714619449351
    },
    {
      "name": "tank.chain",
      "name_fee": 134626900000000000000,
      "auction_end": 965088,
      "last_bid": {
        "block_hash": "mh_bV9Kq1tCMpRWgTAWy6C6vvQy5r2RjganqjFhQcPoRZmwNxZtN",
        "block_height": 935328,
        "encoded_tx": "tx_+JQLAfhCuEA+wsY1qqQhRraS487OtyxOqltUkG8KrnrVoMeGj1Db5XRf/cFdyJ3MhMfE5bgoBx57i9zAKC/iMdQsPzzNf3QFuEz4SiACoQFDfNR5+5vHGV9m03tIkBWvRBxUxZg57c17DFoKdfI/bleKdGFuay5jaGFpbocLZSf1Zg0fiQdMUtREIAlAAIYPBly7UAAAdKgDMw==",
        "hash": "th_2fpQo1jm3VwHkn4VcDxFxaMnNLWc2PD8KA35WZwGDDSYKxJDkx",
        "micro_index": 0,
        "micro_time": 1713926446496,
        "signatures": [
          "sg_9DEUyZZfXQDR7t1QbGod9GztGTeFGCiAuNHzqZaXng6kY9Xbn1hNqbFWVugChgQySzLsNfxhcHRrP7qtjPoCAjaJM57pf"
        ],
        "tx": {
          "account_id": "ak_Wit5Lxv9v3QNYiGSTidCM7Ssuagd7cs6fsBnuwZmULLAWBZd2",
          "fee": 16520000000000,
          "name": "tank.chain",
          "name_fee": 134626900000000000000,
          "name_id": "nm_CCgyYJEUuyZtfZrAZvFK8tv2k9a9zhKkByxhwHcrc64mVw7EB",
          "name_salt": 3207447039053087,
          "nonce": 87,
          "ttl": 1145088,
          "type": "NameClaimTx",
          "version": 2
        }
      },
      "approximate_expire_time": 1719292902317,
      "activation_time": 1713926446496
    }
  ],
  "next": "/v3/names/auctions?cursor=548763-svs.chain&limit=2",
  "prev": null
}
```

To show auctions ordered by name, from the beginning:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/auctions?by=name&direction=forward&limit=100" | jq '.data [] .name'
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

### `/v3/names/:name_or_hash`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/bear.test" | jq '.'
{
  "active": false,
  "name": "bear.test",
  "hash": "nm_2aGpF2uJp1wDpuHoNDhhSztpoQr43dAjzZ5SyvfD2RSKTVmL6X",
  "name_fee": 134626900000000000000,
  "revoke": null,
  "expire_height": 135638,
  "auction_timeout": 0,
  "auction": null,
  "ownership": {
    "current": "ak_2CXSVZqVaGuZsmcRs3CN6wb2b9GKtf7Arwej7ahbeAQ1S8qkmM",
    "original": "ak_2CXSVZqVaGuZsmcRs3CN6wb2b9GKtf7Arwej7ahbeAQ1S8qkmM"
  },
  "active_from": 85624,
  "approximate_expire_time": 1567835676059,
  "approximate_activation_time": 1558792599799
}
```

It's possible to use encoded hash as well:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj" | jq '.'
{
  "active": false,
  "name": "wwwbeaconoidcom.chain",
  "hash": "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj",
  "name_fee": 676500000000000000,
  "revoke": null,
  "expire_height": 329558,
  "auction_timeout": 0,
  "auction": null,
  "ownership": {
  "current": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
  "original": "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
  },
  "active_from": 279555,
  "approximate_expire_time": 1602925509746,
  "approximate_activation_time": 1593861576848
}
```

If the name is currently in auction, the reply has different shape:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v2/names/help" | jq '.'
{
  "active": false,
  "name": "yedianzhiwang.chain",
  "hash": "nm_2akgyVeSqDeynUVTHnHzengLarQyQqC9sHigsrBKnaCtmd3Ca5",
  "name_fee": 1771100000000000000,
  "revoke": null,
  "expire_height": 364002,
  "auction_timeout": 0,
  "auction": {
    "name": "yedianzhiwang.chain",
    "name_fee": 134626900000000000000,
    "auction_end": 965088,
    "last_bid": {
      "block_hash": "mh_bV9Kq1tCMpRWgTAWy6C6vvQy5r2RjganqjFhQcPoRZmwNxZtN",
      "block_height": 935328,
      "encoded_tx": "tx_+JQLAfhCuEA+wsY1qqQhRraS487OtyxOqltUkG8KrnrVoMeGj1Db5XRf/cFdyJ3MhMfE5bgoBx57i9zAKC/iMdQsPzzNf3QFuEz4SiACoQFDfNR5+5vHGV9m03tIkBWvRBxUxZg57c17DFoKdfI/bleKdGFuay5jaGFpbocLZSf1Zg0fiQdMUtREIAlAAIYPBly7UAAAdKgDMw==",
      "hash": "th_2fpQo1jm3VwHkn4VcDxFxaMnNLWc2PD8KA35WZwGDDSYKxJDkx",
      "micro_index": 0,
      "micro_time": 1713926446496,
      "signatures": [
      "sg_9DEUyZZfXQDR7t1QbGod9GztGTeFGCiAuNHzqZaXng6kY9Xbn1hNqbFWVugChgQySzLsNfxhcHRrP7qtjPoCAjaJM57pf"
      ],
      "tx": {
        "account_id": "ak_Wit5Lxv9v3QNYiGSTidCM7Ssuagd7cs6fsBnuwZmULLAWBZd2",
        "fee": 16520000000000,
        "name": "tank.chain",
        "name_fee": 134626900000000000000,
        "name_id": "nm_CCgyYJEUuyZtfZrAZvFK8tv2k9a9zhKkByxhwHcrc64mVw7EB",
        "name_salt": 3207447039053087,
        "nonce": 87,
        "ttl": 1145088,
        "type": "NameClaimTx",
        "version": 2
      }
    },
    "approximate_expire_time": 1719295566979,
    "activation_time": 1713926446496
  },
  "ownership": {
    "current": "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
    "original": "ak_2pqYSBpEkykFy11KFZXxDJaB8KugXBi2JxraqZXpTaXzreYb95"
  },
  "active_from": 163855,
  "approximate_expire_time": 1609161570008,
  "approximate_activation_time": 1572935113556
}
```

### `/v3/names/auctions/:name`

Auction specific name resolution is available behind this endpoint:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/auctions/meta.chain" | jq '.'
{
  "name": "meta.chain",
  "name_fee": 134626900000000000000,
  "auction_end": 968903,
  "last_bid": {
    "block_hash": "mh_2F3vhNXJ1eXaQiAz6RQHzAUW5dEUTSEvxaBAHDn8ziHjrd9FJK",
    "block_height": 939143,
    "encoded_tx": "tx_+JYLAfhCuECFZmpTCOnm3v0zZ3g2BVIZApsjxGt4Q4MWck+gEw0j09Jq61XEgQWafn3fP2oesqcsy6wYGpGWT6eFW/iE7IoCuE74TCACoQH7BL4bl7Y/NrliWEMKWaxk9besmKUYp6PkFk7ZZeieHYIyZ4ptZXRhLmNoYWluhwUXe6y8hW+JB0xS1EQgCUAAhg8PrOrgAADImXsf",
    "hash": "th_2KpsBbibCN4EwtKNtLLAZzRw3AJ7xMEQw5sfbNZjQKCdP5pc5V",
    "micro_index": 0,
    "micro_time": 1714619449351,
    "signatures": [
      "sg_JTFJFCMh84NB9rJiHgzVcCgXsSt5i6njT4E55vLDRVoeXKuB4ETqzt1BB6TtAUrbGoGMYd4iXM7xuwPXXgVoWCPPZu8SS"
    ],
    "tx": {
      "account_id": "ak_2uYw22W3KGCCduExjzkBDNUxWt3Akdehm66CFAXDKRt9aoUofX",
      "fee": 16560000000000,
      "name": "meta.chain",
      "name_fee": 134626900000000000000,
      "name_id": "nm_2ab7LiFhV5uAzXq6EHmMsPm2cHoKaLdFMnwoTrkVaHSUAAZmx5",
      "name_salt": 1433194830005615,
      "nonce": 12903,
      "ttl": 1148903,
      "type": "NameClaimTx",
      "version": 2
    }
  },
  "approximate_expire_time": 1719978527794,
  "activation_time": 1714619449351
}
```

### `/v3/accounts/:account_id/names/pointees`

Returns names pointing to a particular pubkey. Can be scoped by gen using `scope=gen:100-200` query parameter.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/accounts/ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C/names/pointees?limit=3" | jq '.'
{
  "data": [
    {
      "name": "star.chain",
      "key": "account_pubkey",
      "tx": {
        "account_id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
        "client_ttl": 10500,
        "fee": 17860000000000,
        "name_id": "nm_dRChkcZn62toYnPZVjgpi5UsnyMZdHH3zw9ah2JR9ESFga5qK",
        "name_ttl": 50000,
        "nonce": 245,
        "pointers": [
          {
            "id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
            "key": "account_pubkey"
          }
        ],
        "ttl": 272285
      },
      "block_hash": "mh_2ksi3YAh6oYviVooxn93F6vMrYoGhBuX4LgZnBUHszYJSPx5eT",
      "source_tx_type": "NameUpdateTx",
      "source_tx_hash": "th_YfXgjU5LPonGzZRSNedHtzqZLtSLbuorbBV9T2iCPQVcATRNM",
      "block_time": 1592458627198,
      "block_height": 271786
    },
    {
      "name": "store.chain",
      "key": "account_pubkey",
      "tx": {
        "account_id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
        "client_ttl": 10500,
        "fee": 17860000000000,
        "name_id": "nm_2PMNtzqTk38rEMmoVAuFNSJtWQgdtREDWDau497ofQW4XvRydC",
        "name_ttl": 50000,
        "nonce": 244,
        "pointers": [
          {
            "id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
            "key": "account_pubkey"
          }
        ],
        "ttl": 272285
      },
      "block_hash": "mh_jKTG4ThGE2dFyoKDBi2AUgkHrBi8LQEF5NuD2WDuX5jJmpT8n",
      "source_tx_type": "NameUpdateTx",
      "source_tx_hash": "th_2ccvwv8sd4f7UgjCETvmG8wEx5ZSa7wnYzuU3yUyVSJkjhz3Lq",
      "block_time": 1592458574738,
      "block_height": 271785
    },
    {
      "name": "aepps.chain",
      "key": "account_pubkey",
      "tx": {
        "account_id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
        "client_ttl": 10500,
        "fee": 17860000000000,
        "name_id": "nm_zJVQvLaC3DPVKTdrYXvrB8YpQpQFqN6drxUmGbyvTQQWjAcAf",
        "name_ttl": 50000,
        "nonce": 241,
        "pointers": [
          {
            "id": "ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx",
            "key": "account_pubkey"
          }
        ],
        "ttl": 271240
      },
      "block_hash": "mh_SG6qWMrJEtbjfFiUJLeR7KaU5q3GNMMrMCLM1MYEQcafLF3jU",
      "source_tx_type": "NameUpdateTx",
      "source_tx_hash": "th_25nTyhVyLWRwgnkh3VJZnBcNvWpQgEDq1azv3RFyRJXs5eqauV",
      "block_time": 1592269558743,
      "block_height": 270740
    }
  ],
  "next": "/v3/accounts/ak_QyFYYpgJ1vUGk1Lnk8d79WJEVcAtcfuNHqquuP2ADfxsL6yKx/names/pointees?cursor=276059-0-12703951-0-YWNjb3VudF9wdWJrZXk&limit=3",
  "prev": null
}
```

### `/v3/names/:name/claims`

Returns the name claims, paginated.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/vlsl.test/claims" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2Nr1oj3Z3D9sYnEDrNk4SXjboT3otCXQafsNukRcRDg25URKrR",
      "height": 45784,
      "tx": {
        "account_id": "ak_2T42t9vpy56kKfZuX74SHuYGsETi1YegJ1KjBbieBwJswt1QVN",
        "fee": 21000000000000,
        "name": "vlsl.test",
        "name_salt": 123,
        "nonce": 67,
        "ttl": 45882,
        "type": "NameClaimTx",
        "version": 2
      }
    }
  ],
  "next": null,
  "prev": null
}
```

### `/v3/names/:name/transfers`

Returns the name transfers, paginated.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/test.test/transfers" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2wWv1cwnC2purbtZqXiNcZDpX9SAmEUc5YaMKZmSR9p1pEm9rE",
      "height": 42320,
      "tx": {
        "account_id": "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
        "fee": 30000,
        "name_id": "nm_en1mSKcVPb9gY8UGxPfABw3JouEGZ4ZvdfcBWetmn6czUuVG1",
        "nonce": 18550,
        "recipient_id": "ak_2WZoa13VKHCamt2zL9Wid8ovmyvTEUzqBjDNGDNwuqwUQJZG4t",
        "ttl": 42420,
        "type": "NameTransferTx",
        "version": 1
      }
    }
  ],
  "next": null,
  "prev": null
}
```

### `/v3/names/:name/updates`

Returns the name updates, paginated.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/names/ssup.test/updates?limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_qZM3VVCHynY1AG4Pgwcdobg42oGAxhY7c1LrUzqvgJSFLLbPU",
      "height": 45706,
      "tx": {
        "account_id": "ak_2CXSVZqVaGuZsmcRs3CN6wb2b9GKtf7Arwej7ahbeAQ1S8qkmM",
        "client_ttl": 36000,
        "fee": 20000000000000,
        "name_id": "nm_2tokSd7X5zeYzAr5icomaVLBYC3TGeCypsPjZALcQcxYZb4YdP",
        "name_ttl": 50000,
        "nonce": 3544,
        "pointers": [
          {
            "id": "ak_M6MNwGLtMQ4j3m8pzQz9uF38nMfjCCVaiQ8fvTAU6DEsCocD5",
            "key": "account_pubkey"
          }
        ],
        "ttl": 60000,
        "type": "NameUpdateTx",
        "version": 1
      }
    }
  ],
  "next": "/v3/names/ssup.test/updates?cursor=45706-20-1132300&limit=1",
  "prev": null
}
```

---

## Contracts

### `/v3/contracts`

Paginatable list of all non-preset contracts, filterable by scope.

```
curl -s "https://mainnet.aeternity.io/mdw/v3/contracts?limit=1" | jq '.'
{
  "data" : [
    {
      "block_hash" : "mh_2sEDNcQaZwpU4qUZGPX3zV7BruQvzQ4qnYpo4VWaPU6sQfjDqJ",
      "contract" : "ct_D4ZxQD9wXRXYkT7EQd5SiGmySJziEGJSGyDBqH9SwYMsnH4JX",
      "create_tx" : {
        "abi_version" : 3,
        "amount" : 0,
        "call_data" : "cb_KxFE1kQfGwphxkNE",
        "code" : "cb_+GlGA6ANexG+yJOtFvI0ogpw4uOHJDVScNPobxeyUDr10xHM08C4PKH+RNZEHwA3AQc3ABoGggABAz/+iKBvXwA3AQcHFiQAggCWLwIRRNZEHxFpbml0EYigb18RY2FsY4IvAIU3LjEuMAAZ1+t2",
        "deposit" : 0,
        "fee" : 78540000000000,
        "gas" : 76,
        "gas_price" : 1000000000,
        "nonce" : 27,
        "owner_id" : "ak_2oGsfHFUww8cv7Tsc73FJcKWLFmn25Mk1rF68aTxwhwREecrs8",
        "ttl" : 0,
        "vm_version" : 7
      },
      "source_tx_hash" : "th_ZyorKqF8kUac4KFcRcEVeHXsnQ6vfMZei98gekvBwuSdjtEuZ",
      "source_tx_type" : "ContractCreateTx"
    }
  ],
  "next" : "/v3/contracts?cursor=40835756-0&limit=1",
  "prev" : null
}
```

### `/v3/contracts/:id`

Get a single contract.

```
$ curl -s "http://mainnet.aeternity.io/mdw/v3/contracts/ct_D4ZxQD9wXRXYkT7EQd5SiGmySJziEGJSGyDBqH9SwYMsnH4JX" | jq '.'
{
  "block_hash" : "mh_2sEDNcQaZwpU4qUZGPX3zV7BruQvzQ4qnYpo4VWaPU6sQfjDqJ",
  "contract" : "ct_D4ZxQD9wXRXYkT7EQd5SiGmySJziEGJSGyDBqH9SwYMsnH4JX",
  "create_tx" : {
    "abi_version" : 3,
    "amount" : 0,
    "call_data" : "cb_KxFE1kQfGwphxkNE",
    "code" : "cb_+GlGA6ANexG+yJOtFvI0ogpw4uOHJDVScNPobxeyUDr10xHM08C4PKH+RNZEHwA3AQc3ABoGggABAz/+iKBvXwA3AQcHFiQAggCWLwIRRNZEHxFpbml0EYigb18RY2FsY4IvAIU3LjEuMAAZ1+t2",
    "deposit" : 0,
    "fee" : 78540000000000,
    "gas" : 76,
    "gas_price" : 1000000000,
    "nonce" : 27,
    "owner_id" : "ak_2oGsfHFUww8cv7Tsc73FJcKWLFmn25Mk1rF68aTxwhwREecrs8",
    "ttl" : 0,
    "vm_version" : 7
  },
  "source_tx_hash" : "th_ZyorKqF8kUac4KFcRcEVeHXsnQ6vfMZei98gekvBwuSdjtEuZ",
  "source_tx_type" : "ContractCreateTx"
}
```

### `/v3/contracts/logs`

A paginable contract log endpoint allows querying of the contract logs using several querying parameters, including:

- `contract_id` - listing only logs emitted by given contract
- `event` - listing only logs emitted by particular event constructor (base32hex encoded blake2b hash)
- `data` - listing only logs which have `data` field matching the provided prefix
- `function` - the name of the function called
- `aexn-args`- formats the args topics according to the event type

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?direction=forward&contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "32049452134983951870486158652299990269658301415986031571975774292043131948665",
        "10000000000000000"
      ],
      "call_tx_hash": "th_2JLGkWhXbEQxMuEYTxazPurKiwGvo5R6vgqjSBw3R8z9F6b4rv",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "https://github.com/thepiwo",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?direction=forward&contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1"
}
```

The attributes returned on each object are the following:

- `args` - a list of event constructor arguments as big integers. Contract bytecode doesn't contain metadata describing the types of the contract events. As a result, we can only report the binary blobs to the user, which can be either an integer (probably denoting an amount or counter), or public key.
  The integer can be converted to public key (256-bits) binary in Elixir (or Erlang) shell:
  ```
  iex(aeternity@localhost)3> <<32049452134983951870486158652299990269658301415986031571975774292043131948665 :: 256>>
  <<70, 219, 88, 217, 218, 57, 227, 219, 63, 200, 168, 207, 16, 238, 173, 185,
    185, 214, 3, 207, 227, 124, 221, 54, 36, 147, 13, 144, 171, 6, 142, 121>>
  ```

- `call_tx_hash` - hash of contract call transaction which emitted the event log

- `contract_id` - contract identifier

- `data` - decoded (human readable) data field of event log (if any)

- `event_hash` - base32hex encoded blake2b hash of the name of the event constructor
  The source of the contract in question has one of the event log constructors named "TipReceived".
  Its encoded hash can be retrieved as:
  ```
  iex(aeternity@localhost)11> Base.hex_encode32(:aec_hash.blake2b_256_hash("TipReceived"))
  "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0===="
  ```

- `ext_caller_contract_id` - caller contract id, potentially different to `contract_id`, if the contract which emitted the event was called from other contract

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
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "80808227038564992079558295896388926841596253273977977325246416786468530750284",
        "23245441236723951035912846601319239080044515685575576534240736154129181748855",
        "966628800000000000"
      ],
      "call_tx_hash": "th_2vDNSLGyBdBNPmyfWtfHEAH2PdJh7t39G3a6JtM4ByfYD1LT1V",
      "contract_id": "ct_2MgX2e9mdM3epVpmxLQim7SAMF2xTbid4jtyVi4WiLF3Q8ZTRZ",
      "data": "",
      "event_hash": "48U3JOKTVTI6FVMTK2BLHM8NG72JEBG93VS6MENPSC8E71IM5FNG====",
      "ext_caller_contract_id": "ct_2M4mVQCDVxu6mvUrEue1xMafLsoA1bgsfC3uT95F3r1xysaCvE",
      "log_idx": 2
    }
  ],
  "next": "/v3/contracts/logs?cursor=68PJACHK74O3E91J60QJADHG6OR28HA96P258MAL6KRJAKQ7A0RLEDAL8D65CKIN95C52I23AH7KOKAA8GRJ8HQN9TC5KD2D957KGGIJAT350M2H7KUJQF9460I0&limit=1",
  "prev": null
}
```

Listing contract logs in range between generations 200000 and 210000:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?scope=gen:200000-210000&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "48550576960427288418928503238185419255781131458428297160617859112449977313818",
        "1000000000000000000"
      ],
      "call_tx_hash": "th_2BjrnHaRHo196AHtpMHV4QUiJqDi6UjfsA5pbPgTGhKpQuB67N",
      "contract_id": "ct_cT9mSpx9989Js39ag45fih2daephb7YsicsvNdUdEB156gT5C",
      "data": "https://github.com/aeternity",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_cT9mSpx9989Js39ag45fih2daephb7YsicsvNdUdEB156gT5C",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?cursor=6CS34DHK6KQI8D1G60O38DPP4H2KIDI4AHCLAD9N6L9KEK1NASQLAGQCAP95EIAOA5446L2F9H8KKH1N6H3LEJQOB8Q4QIAF91156LQ6A1C52F9T7KUI8C14&limit=1&scope=gen%3A200000-210000",
  "prev": null
}
```

Listing contract logs in generation 250109 only:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?scope=gen:250109&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "113825637927817399496888947973485901133216730124575464244310341957325543404011",
        "100000000000000000"
      ],
      "call_tx_hash": "th_22pciXRFnEieCSMEbcEPEfHdxvJobJt2UoCtXXiQ3pnDn6kvaz",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "https://twitter.com/LeonBlockchain",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?cursor=6CS34DHK6KQI8D1G60O38DPP4H2KIDI4AHCLAD9N6L9KEK1NASQLAGQCAP95EIAOA5446L2F9H8KKH1N6H3LEJQOB8Q4QIAF91156LQ6A1C52F9T7KUI8C14&limit=1&scope=gen%3A250109",
  "prev": null
}
```

Listing latest logs for given contract

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=2" | jq '.'
{
  "data": [
    {
      "args": [
        "87569133758291964643644139664803946495433064832095920406619813370506210782355",
        "120000000000000000"
      ],
      "call_tx_hash": "th_2rQFbvkR2rxvBQLWt4WPUPiSViES8aKDBVDraF4mogdZsVTJSQ",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "https://www.youtube.com/watch?v=iLQzaLr1enE",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "log_idx": 0
    },
    {
      "args": [
        "19315768272296812419334917756530784329195878521494173087129733615253420217233",
        "52300000000000000000"
      ],
      "call_tx_hash": "th_JgxLwr7WszXNT5tU1ngc6fJJyxTywcLjWxXy8sqrpX7r7byCQ",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "https://superhero.com/",
      "event_hash": "ATPGPVQP8277UG86U0JDA2CPFKQ1F28A51VAG9F029836CU1IG80====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=70PJICHN6OR28CPG6GR3GDHK6OI5AH2MACRKOM9LB58KKD9L9DD3AMIKA92KGM269LCKAL9NA12K4DA69HCKGCQC88PKIDHN6TCLAKA2915LKK9T7KUJQ91G4G&limit=2",
  "prev": null
}
```

Listing first logs where data field points to `aeternity.com`:
(The value of data parameter needs to be URL encoded, which is not visible in this example)

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?direction=forward&data=aeternity.com&limit=2" | jq '.'
{
  "data": [
    {
      "args": [
        "69318356919715896655612698359975736845612647472784537635207689589288608801665"
      ],
      "call_tx_hash": "th_29wEBiUVommkJJqtWxczsdTViBSHsCxsQMtyYZb3hju4xW6eFS",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "aeternity.com",
      "event_hash": "K3LIVBOTOG9TTAPTPJH47N5CO4KVF41T5BO7RB1R8UVVOKG17APG====",
      "ext_caller_contract_id": "ct_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
      "log_idx": 0
    },
    {
      "args": [
        "69318356919715896655612698359975736845612647472784537635207689589288608801665"
      ],
      "call_tx_hash": "th_nvrmo5YmrWUW9pr2ohiPWB6FHgok9owi5xbLMpV2pHYvECxTD",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "aeternity.com",
      "event_hash": "K3LIVBOTOG9TTAPTPJH47N5CO4KVF41T5BO7RB1R8UVVOKG17APG====",
      "ext_caller_contract_id": "ct_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?cursor=70PJICHN6OR28C9K6SQ3IC1L74I5EDQH6OP4IHQ29TAJ6M2C9L8JCJA48P444GIQ99BK6KHK6SP54KA6B124KJAF8P6KQKPM6944MKAL90R3CG9T7KUJQ91G4HGMAT35E9N6IT3P5PHMUR8&data=aeternity.com&direction=forward&limit=2",
  "prev": null
}
```

Listing the last "TipReceived" event:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/logs?event=TipReceived&limit=1" | jq '.'
{
  "data": [
    {
      "args": [
        "87569133758291964643644139664803946495433064832095920406619813370506210782355",
        "120000000000000000"
      ],
      "call_tx_hash": "th_2rQFbvkR2rxvBQLWt4WPUPiSViES8aKDBVDraF4mogdZsVTJSQ",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "data": "https://www.youtube.com/watch?v=iLQzaLr1enE",
      "event_hash": "MVGUQ861EKRNBCGUC35711P9M2HSVQHG5N39CE5CCIUQ7AGK7UU0====",
      "ext_caller_contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "log_idx": 0
    }
  ],
  "next": "/v3/contracts/logs?cursor=70PJICHN6OR28CPG64R3ADHN6CI5EDQH6OP4IHQ29TAJ6M2C9L8JCJA48P444GIQ99BK6KHK6SP54KA6B124KJAF8P6KQKPM6944MKAL90R3CG9T7KUJQ91G4G&event=TipReceived&limit=1",
  "prev": null
}
```

### `/v3/contracts/calls`

A running contract can call other functions during execution. These calls are recorded and can be queried later.

The query accepts following filters:

- `fname` - The prefix of the name of the function
- `contract` - The contract for the calls
- ID field - Any field belonging to the contract call transaction

#### Using contract id

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/calls?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_25eLkLkkMDRg5Sau1ezeNteAXxzAnfECqeN318hTFLifozJkpt",
      "call_tx_hash": "th_gTNykxuM2MJ4D2Y7L5EoU7wKprmM6rLmAKe2yaBrjbNudMeSq",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
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
  "next": "/v3/contracts/calls?contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&cursor=6CO3ACPK6GRJI91J4GS36E9I6SR3C9144GMJ2C1G&limit=1",
  "prev": null
}
```

Using function prefix

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/calls?direction=forward&function=Oracle&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2XAPbotBm5qgkWn165g3J7eRsfV9r5tEwSEqS3rggR6b9fRbW",
      "call_tx_hash": "th_4q3cLesnXqSSH3HmecGMSUuZZNKsue8rGMACtCRmFpZtpAXPH",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
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
  "next": "/v3/contracts/calls?cursor=70Q30D1N70OI8C945KOJ0C144H53AMI78DCJ6JADALC4GGPL9H34UIHKA4I2QC9G60&direction=forward&function=Oracle&limit=1",
  "prev": null
}
```

Using ID field

Following ID fields are recognized: `account_id`, `caller_id`, `channel_id`, `commitment_id`, `from_id`, `ga_id`, `initiator_id`, `name_id`, `oracle_id`, `owner_id`, `payer_id`, `recipient_id`, `responder_id`, `sender_id`, `to_id`.

Contract_id field is inaccessible via this lookup, as when present in query, it filters only contracts with given contract id and doesn't look into internal transaction's fields.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/contracts/calls?recipient_id=ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs&limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2Mp1FfJyEaQUYbBKywWb6kWGm1KoTEyc4SZgt7oA7orz9BpSLD",
      "call_tx_hash": "th_XnXh22b9XsXGPEE9ZJwm4E9FuMhv47Z2ogQo6Lgt4npEwVF9W",
      "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
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
  "next": "/v3/contracts/calls?cursor=70S34C1K68S28D145KOJ0C14A93KQGHK9D3K4I258H546JQC99A5IL25AHCL6GPN9T4KIMIB6D2KSKI88P4LKL2M6923AJA16T65ILPJ698I891I&limit=1&recipient_id=ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs",
  "prev": null
}
```

---

## Internal transfers

### `/v3/transfers`

During the operation of the node, several kinds of internal transfers happen which are not visible on general transaction ledger.

Besides specifying of scope and direction as with other streaming endpoints (via forward/backward or gen), the query accepts following filters:

- `kind`. At the moment, following kinds of transfers can be queried:
	- `fee_spend_name` (fee for placing bid to the name auction)
  - `fee_refund_name` (returned fee when the new name bid outbids the previous one in the name auction)
	- `fee_lock_name` (locked fee of the name auction winning)
	- `reward_oracle` (reward for the operator of the oracle (on transaction basis))
  - `reward_block` (reward for the miner (on block basis))
  - `reward_dev` (reward for funding of the development (on block basis))
  - `accounts_minerva`, `accounts_fortuna` and `accounts_lima` (added on hardforks including migrated ERC20 amounts)

	It it possible to provide just a prefix of the kind in interest, e.g.: "reward" will return all rewards, "fee" will return all fees,
  "accounts" will return credits after hardforks.

- `account` - account which received rewards or that was charged fees or that received tokens after a hardfork migration.

Listing internal transfers in range

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transfers?scope=gen:50002-70000&limit=3" | jq '.'
{
  "data": [
    {
      "kind": "reward_block",
      "account_id": "ak_542o93BKHiANzqNaFj6UurrJuDuxU61zCGr9LJCwtTUg34kWt",
      "height": 50002,
      "amount": 218400000000000,
      "ref_tx_type": null,
      "ref_tx_hash": null,
      "ref_block_hash": null
    },
    {
      "kind": "reward_block",
      "account_id": "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
      "height": 50002,
      "amount": 407000327600000000000,
      "ref_tx_type": null,
      "ref_tx_hash": null,
      "ref_block_hash": null
    },
    {
      "kind": "fee_lock_name",
      "account_id": "ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J",
      "height": 50002,
      "amount": 3,
      "ref_tx_type": "mh_2C2KBh8e82yR1TrwrbarNmoNrL1KQG3i29ykooKSTMa7kFJtjF",
      "ref_tx_hash": "th_zUk7eWXjqyUK49WU3ZkLinrRRhMHPRSG22CSb4NbqZjmn7xdm",
      "ref_block_hash": "NameClaimTx"
    }
  ],
  "next": "/v3/transfers?cursor=6KO30C1I5GOJAC9M60S32B1G4HJ6APAVDHNM6QQVDPGMQP948DB54L2FAH356HIN6T84CGHK6GQ4UJ2O6P94ODAM9P248DI69553ECQN899J6KQ4A1CJ6DHN8D7L0GHNA58I8C9L64R30E1H4GO0&limit=3&scope=gen%3A50002-70000",
  "prev": null
}
```

Listing internal transfers of a specific kind

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transfers?direction=forward&kind=reward_dev&limit=2" | jq '.'
{
  "data": [
    {
      "kind": "reward_dev",
      "account_id": "ak_2KAcA2Pp1nrR8Wkt3FtCkReGzAi8vJ9Snxa4PcmrthVx8AhPe8",
      "height": 90981,
      "amount": 37496010998100000000,
      "ref_tx_type": null,
      "ref_tx_hash": null,
      "ref_block_hash": null
    },
    {
      "kind": "reward_dev",
      "account_id": "ak_2KAcA2Pp1nrR8Wkt3FtCkReGzAi8vJ9Snxa4PcmrthVx8AhPe8",
      "height": 90982,
      "amount": 37496003679840000000,
      "ref_tx_type": null,
      "ref_tx_hash": null,
      "ref_block_hash": null
    }
  ],
  "next": "/v3/transfers?cursor=74O3IE1J5GO2OC94E9INEOBICHFM8PBM4HB58MAP85B4OLAE88PLIDQI9H542L219T158DI9A9658HI96DD4EJ25A4R3CHIF99BJCD1L8D2LKD2EAT2K291G4GOG&direction=forward&kind=reward_dev&limit=2",
  "prev": null
}
```

Listing internal transfers related to specific account

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/transfers?account=ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J&limit=1" | jq '.'
{
  "data": [
    {
      "kind": "fee_lock_name",
      "account_id": "ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J",
      "height": 51366,
      "amount": 3,
      "ref_tx_type": "mh_2BMVuVLTbt5rsYn8k1gjmKcSQyPwhCEtydtdSVh6TFZYZt99Z7",
      "ref_tx_hash": "th_25CKbSP17N454zjtWdZBmJC4HSyk7USFJfQieyLufXwTKMcwna",
      "ref_block_hash": "NameClaimTx"
    }
  ],
  "next": "/v3/transfers?account=ak_7myFYvagcqh8AtWEuHL4zKDGfJj5bmacNZS8RoUh5qmam1a3J&cursor=6KOJ4CHH5GOJCDHG70P3GB1G4HJ6APAVDHNM6QQVDPGMQP9488QL4HHJA57K6CIPACR5EIA79T6KKJ9I6L648HQI6LD48LQ4B93KQDPIAD1KIHAIALCK4HPLAL8J8DAKA10I8C9M6OO3GCHO4GO0&limit=1",
  "prev": null
}
```

---

## Oracles

There are several endpoints for fetching information about the oracles.

Oracles in Aeternity blockchain have a lifecycle formed by several types of transactions, similar to the Name objects.

### `/v3/oracles`

There is only paginable endpoint for listing oracles, which can be filtered by `scope` (e.g. `gen:100-200`) or state (`active` or `inactive`).

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/oracles?direction=forward&limit=1" | jq '.'
{
  "data": [
    {
      "active": false,
      "active_from": 4608,
      "expire_height": 5851,
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
        }
      }
    }
  ],
  "next": "/v3/oracles?cursor=6894-ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM&direction=forward&limit=1",
  "prev": null
}
```

Inactive oracles

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/oracles?state=inactive&limit=1" | jq '.'
{
  "data": [
    {
      "active": false,
      "active_from": 307850,
      "expire_height": 308350,
      "format": {
        "query": "string",
        "response": "string"
      },
      "oracle": "ok_sezvMRsriPfWdphKmv293hEiyeyUYSoqkWqW7AcAuW9jdkCnT",
      "query_fee": 20000000000000,
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
        }
      }
    }
  ],
  "next": "/v3/oracles?state=inactive&cursor=507223-ok_26QSujxMBhg67YhbgvjQvsFfGdBrK9ddG4rENEGUq2EdsyfMTC&direction=backward&limit=1",
  "prev": null
}
```

Active oracles

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/oracles?state=active&limit=1" | jq '.'
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
  "next": "/v3/oracles?state=active&cursor=1289003-ok_f9vDQvr1cFAQAesYA16vjvBX9TFeWUB4Gb7WJkwfYSkL1CpDx&limit=1",
  "prev": null
}
```

### `/v3/oracles/:id/queries`

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/oracles/ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM/queries" | jq '.'
{
  "data": [
    {
      "response": {
        "height": 4662,
        "block_hash": "mh_N2Lg6sLvnHP3eGNp4NB15CiUP3N4TbG5jTjY69HaECs33Z5MS",
        "query_id": "oq_fKwkWDh1Ze4iWGaMBjGCu69LKNkzYwndrcnPwLatVDdWe3MF9",
        "block_time": 1544195139953,
        "source_tx_hash": "th_8Se3Gxt1SYUL7jBAxB33KXDSmp4nh282JqF16CVUmb7wBCvoy",
        "source_tx_type": "OracleRespondTx",
        "fee": 20000,
        "nonce": 198,
        "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
        "response": "T3JhY2xlcyBpbiBBZXRlcm5pdHkgYXJlIHdvcmtpbmcu",
        "response_ttl": {
          "type": "delta",
          "value": 1000
        },
        "ttl": 0
      },
      "height": 4662,
      "block_hash": "mh_vMjtRSPkkkZFhdWcB7Qs2eCWx7deLShL3sW8ANmjijTS5Kmrt",
      "query_id": "oq_fKwkWDh1Ze4iWGaMBjGCu69LKNkzYwndrcnPwLatVDdWe3MF9",
      "block_time": 1544195030464,
      "source_tx_hash": "th_VNYE1rRfjPD66hjgGUBzaqwdGm4PPmzULZAcqnLcWMvrSWehz",
      "source_tx_type": "OracleQueryTx",
      "fee": 20000,
      "nonce": 197,
      "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
      "query": "QXJlIG9yYWNsZXMgaW4gYWV0ZXJuaXR5IHdvcmtpbmc/",
      "query_fee": 20000,
      "query_ttl": {
        "type": "delta",
        "value": 1000
      },
      "response_ttl": {
        "type": "delta",
        "value": 1000
      },
      "sender_id": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
      "ttl": 0
    }
  ],
  "next": null,
  "prev": null
}
```

### `/v3/oracles/:id/responses`

Paginated list of an oracle's responses to queries.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/oracles/ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM/responses?limit=1" | jq '.'
{
  "data": [
    {
      "height": 4662,
      "block_hash": "mh_N2Lg6sLvnHP3eGNp4NB15CiUP3N4TbG5jTjY69HaECs33Z5MS",
      "query": {
        "height": 4662,
        "block_hash": "mh_vMjtRSPkkkZFhdWcB7Qs2eCWx7deLShL3sW8ANmjijTS5Kmrt",
        "query_id": "oq_fKwkWDh1Ze4iWGaMBjGCu69LKNkzYwndrcnPwLatVDdWe3MF9",
        "block_time": 1544195030464,
        "source_tx_hash": "th_VNYE1rRfjPD66hjgGUBzaqwdGm4PPmzULZAcqnLcWMvrSWehz",
        "source_tx_type": "OracleQueryTx",
        "fee": 20000,
        "nonce": 197,
        "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
        "query": "QXJlIG9yYWNsZXMgaW4gYWV0ZXJuaXR5IHdvcmtpbmc/",
        "query_fee": 20000,
        "query_ttl": {
          "type": "delta",
          "value": 1000
        },
        "response_ttl": {
          "type": "delta",
          "value": 1000
        },
        "sender_id": "ak_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
        "ttl": 0
      },
      "query_id": "oq_fKwkWDh1Ze4iWGaMBjGCu69LKNkzYwndrcnPwLatVDdWe3MF9",
      "block_time": 1544195139953,
      "source_tx_hash": "th_8Se3Gxt1SYUL7jBAxB33KXDSmp4nh282JqF16CVUmb7wBCvoy",
      "source_tx_type": "OracleRespondTx",
      "fee": 20000,
      "nonce": 198,
      "oracle_id": "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
      "response": "T3JhY2xlcyBpbiBBZXRlcm5pdHkgYXJlIHdvcmtpbmcu",
      "response_ttl": {
        "type": "delta",
        "value": 1000
      },
      "ttl": 0
    }
  ],
  "next": null,
  "prev": null
}
```

---

## Channels

### `/v3/channels`

Returns active channels ordered by the txi of the last update.

These can also be filtered by `state=active` or `state=inactive`.

Besides the participants balances it includes some fields intrinsic to the channel such as:
- the reserve deposited in the channel for paying fees and assuring refunds;
- lock parameters, in case of individual actions; and
- delegates allowed to represent participants

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/channels?direction=forward&limit=1" | jq '.'
{
  "data": [
    {
      "active": true,
      "amount": 100090,
      "channel": "ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD",
      "initiator": "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS",
      "last_updated_height": 14258,
      "last_updated_tx_hash": "th_2Ph5XF3VBUNstN5kkVic56NY55xq8vckM3h2TQ5sRVSLGq1kvE",
      "last_updated_tx_type": "ChannelDepositTx",
      "responder": "ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq",
      "state_hash": "st_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACy1gTH9",
      "updates_count": 3,
      "channel_reserve": 10,
      "delegate_ids": [],
      "initiator_amount": 50000,
      "lock_period": 3,
      "locked_until": 0,
      "responder_amount": 50000,
      "round": 6,
      "solo_round": 0
    }
  ],
  "next": "/v3/channels?cursor=9155-ch_2tceSwiqxgBcPirX3VYgW3sXgQdJeHjrNWHhLWyfZL7pT4gZF4&direction=forward&limit=1",
  "prev": null
}
```

### `/v3/channels/:id`

Returns the state of an active/inactive channel.

Optionally a `block_hash` parameter might be used to query for the state on a specific block.

In this example it retrieves the `ChannelDepositTx` as the last udpate for a block prior to the last update that was a `ChannelCloseMutualTx`.

```
$ curl -s "https://testnet.aeternity.io/mdw/v3/channels/ch_2ZBf9AJ3wr25YzdZb1sQrDALEQ1ZDKwwUhtVXoZiNKbheuesqs?block_hash=mh_245PQCb1gWrJRxUjAmEAv5qSXLQGnksCgHyw9PTHRNGA6PfeD" | jq '.'
{
  "active": true,
  "amount": 1e+19,
  "channel": "ch_2ZBf9AJ3wr25YzdZb1sQrDALEQ1ZDKwwUhtVXoZiNKbheuesqs",
  "initiator": "ak_VQbiKWLmFXzamGXeTahL9efE8jMprjM9ZpG2BXyWYmPy3ck9Q",
  "last_updated_height": 104024,
  "last_updated_tx_hash": "th_2SQMPNd8jdY5nm8YFpitUti8z9qqBfPuzdodQU9FFzpuMxuLYw",
  "last_updated_tx_type": "ChannelDepositTx",
  "responder": "ak_27c4YpfUuW4s9T6RBNpASNuDRiXSWQ93uZ5WxaUXfx1Lqibv33",
  "state_hash": "st_7oYjZ20LNQTH1ICHzQvgmgAKcYgqFP5hiv8ATvu+5y6a4j9h",
  "updates_count": 3,
  "channel_reserve": 1e+18,
  "delegate_ids": [],
  "initiator_amount": 2e+18,
  "lock_period": 10,
  "locked_until": 0,
  "responder_amount": 2e+18,
  "round": 8,
  "solo_round": 0
}
```

### `/v3/channels/:id/updates`

Returns a paginated list of updates done to a channel.

```
$ curl -s "https://testnet.aeternity.io/mdw/v3/channels/ch_2ZBf9AJ3wr25YzdZb1sQrDALEQ1ZDKwwUhtVXoZiNKbheuesqs/updates?limit=1" | jq '.'
{
  "data": [
    {
      "block_hash": "mh_2QuuJR9TC7Pnq2o8myDgEQWnRxbCtYwenLLGrk1Xr1VmjF5ozt",
      "source_tx_hash": "th_2YHpkkn9ojgKF8amcJiaLCPR46JZg9He6T73MRHdM21Nj2QSWn",
      "source_tx_type": "ChannelCreateTx",
      "tx" => {
        "channel": "ch_2ZBf9AJ3wr25YzdZb1sQrDALEQ1ZDKwwUhtVXoZiNKbheuesqs",
        "tx_type": "ChannelCreateTx",
        "channel_reserve": 1,
        "delegate_ids": [],
        "fee": 17500000000000,
        "initiator_amount": 20000000000000,
        "initiator_id": "ak_vx8HkCzRHrqpCAyQ7TFBtfTqBimkcTFcJC1amez5vtCzdu2oN",
        "lock_period": 1,
        "nonce": 7,
        "responder_amount": 1,
        "responder_id": "ak_2dxvgsogiBDWXvZSzTghv5MoXLfkFGiEynDC5Cn8k2M2s325Ki",
        "state_hash": "st_fav83CO2VqFQTOayQE3Z3Xhj1NTbFHNcve7KWjemmES0s7tK",
        "ttl": 0
      }
    }
  ],
  "next": "/v3/channels/ch_2ZBf9AJ3wr25YzdZb1sQrDALEQ1ZDKwwUhtVXoZiNKbheuesqs/updates?cursor=9155-0&limit=1",
  "prev": null
}
```

## AEX9 tokens

AEx9 tokens standard is defined by AEX9 (https://github.com/aeternity/AEXs/blob/master/AEXS/aex-9.md).

### `/v3/aex9`

Returns paginated list of AEx9 contracts. Can be sorted with the `by` query parameter by `name` (default), `symbol` or `creation`.

These endpoints accepts an optiona parameter of `prefix` OR `exact` for listing tokens with the name or symbol, which are matching either by prefix, or exactly.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/aex9?by=symbol" | jq '.'
{
  "data": [
    {
    "decimals": 18,
    "name": "yy",
    "extensions": [],
    "symbol": "yy",
    "contract_id": "ct_ukZe6BBpuSWxT8hxd87z11vdgRnwKnedEWqJ7SyQucbX1C1pc",
    "contract_tx_hash": "th_236RbbgokHipFbG5Eu9yZSSgzrBQhkRrkFdhXM7ipsmorbkqgy",
    "event_supply": 1e+26,
    "holders": 1,
    "initial_supply": 1e+26
    },
    {
    "decimals": 18,
    "name": "xx",
    "extensions": [],
    "symbol": "xx",
    "contract_id": "ct_vJWj5Z9KPBSE52ZvbZ9cffRhEEX6K6DjRwAZcZ9bArDmrZDuS",
    "contract_tx_hash": "th_2B6DM7SLqRkcTRBejLR4fohBpa4k3nR164uUja3k8SKKYvbwdJ",
    "event_supply": 2e+25,
    "holders": 4,
    "initial_supply": 2e+25
    }
  ],
  "next": "/v3/aex9?by=symbol&cursor=g2gDdwRhZXg5bQAAAAN4b2ttAAAAIHUgUMyJxcMnebj7f5xFL1tWPOn3pfdez%2FvPSy04W1ws",
  "prev": null
}
```

### `/v3/aex9/:contract_id`

```
$ curl https://mainnet.aeternity.io/mdw/v3/aex9/ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9
{
  "decimals": 18,
  "name": "🚀",
  "extensions": [
    "allowances",
    "mintable",
    "burnable",
    "swappable"
  ],
  "symbol": "🚀",
  "contract_id": "ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9",
  "contract_tx_hash": "th_rbFNrRDpn6finytCEmHAExtBnRxt14yckvuCWRmXxsRpypHxt",
  "event_supply": 99000000000000000000,
  "holders": 2,
  "initial_supply": 99000000000000000000
}
```

### `/v3/aex9/:contract_id/balances`

```
$ curl https://mainnet.aeternity.io/mdw/v3/aex9/ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9/balances
{
  "data": [
    {
      "height": 359828,
      "amount": 24000000000000000000,
      "contract_id": "ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9",
      "block_hash": "mh_22uNd2u5ogsFCua2kU3fSag758fTcwJ4kKJwvHpRVedeKwFRHc",
      "account_id": "ak_2KnhztVzfKMBUogdSsCACKVotb6uxjqDLLcLsTk8MdW3266YTL",
      "last_tx_hash": "th_2d2Qnx632buohPC6jmu9jwm5m4vbbegcAiwwZevoJJLeru2MVZ",
      "last_log_idx": 0
    },
    {
      "height": 359828,
      "amount": 75000000000000000000,
      "contract_id": "ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9",
      "block_hash": "mh_22uNd2u5ogsFCua2kU3fSag758fTcwJ4kKJwvHpRVedeKwFRHc",
      "account_id": "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2",
      "last_tx_hash": "th_2d2Qnx632buohPC6jmu9jwm5m4vbbegcAiwwZevoJJLeru2MVZ",
      "last_log_idx": 0
    }
  ],
  "next": null,
  "prev": null
}
```

### `/v3/aex9/:contract_id/balances/:account_id`

```
$ curl https://mainnet.aeternity.io/mdw/v3/aex9/ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9/balances/ak_2KnhztVzfKMBUogdSsCACKVotb6uxjqDLLcLsTk8MdW3266YTL
{
  "contract": "ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9",
  "account": "ak_2KnhztVzfKMBUogdSsCACKVotb6uxjqDLLcLsTk8MdW3266YTL",
  "amount": 24000000000000000000
}
```

### `/v3/aex9/:contract_id/transfers`

```
$ TODO
```

---

## NFTs (AEX-141 contracts and tokens)

AEX-141 NFT contracts might organize the access and storage of NFTs metadata in flexible ways. This behaviour is declared during contract creation with the metadata_type field. This and other meta_info fields like name and symbol can be accessed by `/aex141` endpoint that displays information about NFT contracts.

### `/v3/aex141`

Returns creation and stats information in default paginated way for all NFT collections.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141?direction=forward&limit=1' | jq '.'
{
  "data": [
    {
      "base_url": null,
      "contract_id": "ct_2KsfvrPHwdZb9CkwvgCkzg4o4k7cH7oyfQq4CNPNCHEZ4RTCf",
      "contract_txi": 30958504,
      "extensions": [
        "mintable"
      ],
      "metadata_type": "map",
      "name": "Apes stepping into the Metaverse",
      "nft_owners": 1,
      "nfts_amount": 8,
      "symbol": "ASITM"
    }
  ],
  "next": "/v3/aex141?cursor=g2gDZAAGYWV4MTQxbQAAACBBcGVzIHN0ZXBwaW5nIGludG8gdGhlIE1ldGF2ZXJzZW0AAAAgD29qcQzT%2FM%2BHEg1uw31I%2BYRUpktYP%2FZ09Dapkl2szkA%3D&direction=forward&limit=1",
  "prev": null
}
```

### `/v3/aex141/:contract_id`

Returns creation and stats information for a specific NFT collection.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8' | jq .
{
  "base_url": null,
  "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
  "contract_txi": 30958726,
  "extensions": [
    "mintable"
  ],
  "metadata_type": "map",
  "name": "Apes stepping into the Metaverse",
  "nft_owners": 1,
  "nfts_amount": 8,
  "symbol": "ASITM"
}
```

### `/v3/aex141/:contract_id/tokens`

Returns the tokens of a collection in paginated way.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8/tokens?direction=forward&limit=2' | jq .
{
  "data": [
    {
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "owner_id": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "token_id": 1
    },
    {
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "owner_id": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "token_id": 2
    }
  ],
  "next": "/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8/tokens?cursor=g2gCbQAAACD5nNNdNGQ3YrwVYeXgdeB%2FFd1jOgwZs1p74F2dVz6zC2ED&direction=forward&limit=2",
  "prev": null
}
```

### `/v3/aex141/:contract_id/tokens/:token_id`

Returns the owner wallet address of a NFT.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8/tokens/2' | jq .

{
  "data": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW"
}
```

### `/v3/aex141/:contract_id/templates`

Returns the NFT templates of a collection in paginated way.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_2oq4kSd4j1VkkbupueXLdHwYEJdY8Ntzvp1FFkMB1gYyXkYPcV/templates?direction=forward&limit=2' | jq .

{
  "data": [
    {
      "contract_id": "ct_2oq4kSd4j1VkkbupueXLdHwYEJdY8Ntzvp1FFkMB1gYyXkYPcV",
      "edition": null,
      "log_idx": 0,
      "template_id": 1,
      "tx_hash": "th_KsfMGhkVf2n5RLY5qh1Bo8HppudiQREq7LMKAYuauLSuYKg4s"
    },
    {
      "contract_id": "ct_2oq4kSd4j1VkkbupueXLdHwYEJdY8Ntzvp1FFkMB1gYyXkYPcV",
      "edition": null,
      "log_idx": 0,
      "template_id": 2,
      "tx_hash": "th_Vrk8UGyUpgnvVPK3TknudxPx3Jd3mSCUPnfqcuKbjWZSZivjQ"
    }
  ],
  "next": "/v3/aex141/ct_2oq4kSd4j1VkkbupueXLdHwYEJdY8Ntzvp1FFkMB1gYyXkYPcV/templates?cursor=g2gCbQAAACDuBsFrXLJEIAr8CpUxUAJxriYxXg%2BRMhW900GbowEFwWED&direction=forward&limit=2",
  "prev": null
}
```

### `/v3/aex141/:contract_id/templates/:template_id/tokens`

Returns the NFTs from a collection template in paginated way.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_ouWFCU2Qg6v7dgFpjRc3jAfcaRhb9iByPRBDjXSJoA8fRrQ4j/templates/8/tokens?direction=forward&limit=2' | jq .
{
  "data": [
    {
      "log_idx": 0,
      "owner_id": "ak_8Ujt76QfpT1DyYsNZKGPGtMZ2C2MFf7CcnpQvJWNsX6szZkYN",
      "token_id": 29,
      "tx_hash": "th_ZzPmumNtkYCfrGpVGtQP6em9hgkWQqstddB5ynagrJJa7ua9c"
    },
    {
      "log_idx": 0,
      "owner_id": "ak_8Ujt76QfpT1DyYsNZKGPGtMZ2C2MFf7CcnpQvJWNsX6szZkYN",
      "token_id": 30,
      "tx_hash": "th_2UAUi3oYgcYsJ8EGvxR4vurygt7qhYq7tVRNx4g2sZ3quVpym7"
    }
  ],
  "next": "/v3/aex141/ct_ouWFCU2Qg6v7dgFpjRc3jAfcaRhb9iByPRBDjXSJoA8fRrQ4j/templates/8/tokens?cursor=g2gDbQAAACBqgQyEWHrcaKnZMsVhZvJdUfhMZjSF4KpvuLx%2FpHpCcmEIYR8%3D&direction=forward&limit=2",
  "prev": null
}
```

### `/v3/accounts/:account_id/aex141/tokens`

Returns each NFT owned by a wallet in paginated way.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/accounts/ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW/tokens?direction=forward&limit=2' | jq .
{
  "data": [
    {
      "contract_id": "ct_2KsfvrPHwdZb9CkwvgCkzg4o4k7cH7oyfQq4CNPNCHEZ4RTCf",
      "owner_id": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "token_id": 1
    },
    {
      "contract_id": "ct_2KsfvrPHwdZb9CkwvgCkzg4o4k7cH7oyfQq4CNPNCHEZ4RTCf",
      "owner_id": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "token_id": 2
    }
  ],
  "next": "/v3/accounts/ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW/aex141/tokens?cursor=g2gDbQAAACA1VnHPFWKr80aBDnG3tjrWGYMqQpxUJK6dhDlBrJXgEG0AAAAgAwJumVbCVqhk2XF8UnTR8fiNve0Gh9zLEEoZoC55qRdhAw%3D%3D&direction=forward&limit=2",
  "prev": null
}
```

### `/v3/aex141/:contract_id/transfers`

Returns all NFT transfers involving a NFT collection in paginated way.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8/transfers?direction=forward&limit=2' | jq .
{
  "data": [
    {
      "block_height": 651434,
      "call_txi": 30958727,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 5,
      "micro_time": 1661491608237,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 1,
      "tx_hash": "th_2d5iaRa2DkgJb6ABSt5ea6TcM1FVB2EW6dx7FRU9XMWi1J4n9e"
    },
    {
      "block_height": 651434,
      "call_txi": 30958729,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 6,
      "micro_time": 1661491611260,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 2,
      "tx_hash": "th_BPiUgq2aqm7rTmhb68DW2vEhReWda3mioxeFBjPfxGtLnkAtg"
    }
  ],
  "next": "/v3/aex141/ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8/transfers?cursor=g2gGYgHYZIZtAAAAIPmc0100ZDdivBVh5eB14H8V3WM6DBmzWnvgXZ1XPrMLYgHYZIttAAAAIDVWcc8VYqvzRoEOcbe2OtYZgypCnFQkrp2EOUGsleAQYQNhAA%3D%3D&direction=forward&limit=2",
  "prev": null
}
```

### `/v3/aex141/transfers`

Returns paginated NFT transfers where you can filter by an account being the sender, recpient or both.

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/transfers?from=ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8&direction=forward&limit=2' | jq .
{
  "data": [
    {
      "block_height": 651434,
      "call_txi": 30958727,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 5,
      "micro_time": 1661491608237,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 1,
      "tx_hash": "th_2d5iaRa2DkgJb6ABSt5ea6TcM1FVB2EW6dx7FRU9XMWi1J4n9e"
    },
    {
      "block_height": 651434,
      "call_txi": 30958729,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 6,
      "micro_time": 1661491611260,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 2,
      "tx_hash": "th_BPiUgq2aqm7rTmhb68DW2vEhReWda3mioxeFBjPfxGtLnkAtg"
    }
  ],
  "next": "/v3/aex141/transfers?from=ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8&cursor=g2gGYgHYZIZtAAAAIPmc0100ZDdivBVh5eB14H8V3WM6DBmzWnvgXZ1XPrMLYgHYZIttAAAAIDVWcc8VYqvzRoEOcbe2OtYZgypCnFQkrp2EOUGsleAQYQNhAA%3D%3D&direction=forward&limit=2",
  "prev": null
}
```

```
$ curl -s 'https://testnet.aeternity.io/mdw/v3/aex141/transfers?to=ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW&contract_id=ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8&direction=forward&limit=2' | jq .
{
  "data": [
    {
      "block_height": 651434,
      "call_txi": 30958727,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 5,
      "micro_time": 1661491608237,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 1,
      "tx_hash": "th_2d5iaRa2DkgJb6ABSt5ea6TcM1FVB2EW6dx7FRU9XMWi1J4n9e"
    },
    {
      "block_height": 651434,
      "call_txi": 30958729,
      "contract_id": "ct_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "log_idx": 0,
      "micro_index": 6,
      "micro_time": 1661491611260,
      "recipient": "ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW",
      "sender": "ak_2tw26RwgNADrpuCnrQWKPBH87bPxuRbLR1KLccS9ZJTUMMj4z8",
      "token_id": 2,
      "tx_hash": "th_BPiUgq2aqm7rTmhb68DW2vEhReWda3mioxeFBjPfxGtLnkAtg"
    }
  ],
  "next": "/v3/aex141/transfers?to=ak_QVSUoGrJ31CVxWpvgvwQ7PUPFgnvWQouUgsDBVoGjuT7hjQYW&cursor=g2gGYgHYZIZtAAAAIDVWcc8VYqvzRoEOcbe2OtYZgypCnFQkrp2EOUGsleAQYgHYZIttAAAAIPmc0100ZDdivBVh5eB14H8V3WM6DBmzWnvgXZ1XPrMLYQNhAA%3D%3D&direction=forward&limit=2",
  "prev": null
}
```

---

## Statistics

### `/v3/deltastats`

To show a statistics for a given height, we can use "stats" endpoint:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/deltastats?limit=1" | jq '.'
{
  "data": [
    {
      "auctions_started": 0,
      "block_reward": 0,
      "burned_in_auctions": 0,
      "channels_closed": 0,
      "channels_opened": 0,
      "contracts_created": 0,
      "dev_reward": 0,
      "height": 1,
      "last_tx_hash": "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
      "locked_in_auctions": 0,
      "locked_in_channels": 0,
      "names_activated": 0,
      "names_expired": 0,
      "names_revoked": 0,
      "oracles_expired": 0,
      "oracles_registered": 0
    }
  ],
  "next": "/v3/deltastats?limit=1&cursor=419208"
}
```

### `/v3/totalstats`

Aggregated (summarized) statistics are also available, showing the total sum of rewards and the token supply:

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/totalstats?scope=gen:421454-0&limit=1" | jq '.'
{
  "data": [
    {
      "active_auctions": 0,
      "active_names": 0,
      "active_oracles": 0,
      "burned_in_auctions": 0,
      "contracts": 0,
      "height": 421454,
      "inactive_names": 0,
      "inactive_oracles": 0,
      "last_tx_hash": "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
      "locked_in_auctions": 0,
      "locked_in_channels": 0,
      "open_channels": 0,
      "sum_block_reward": 0,
      "sum_dev_reward": 0,
      "total_token_supply": 8.945137682239798e+25
    }
  ],
  "next": "/v3/totalstats?scope=gen:421454-0&limit=1&cursor=42152"
}
```

These endpoints allow pagination, with typical `forward/backward` direction or scope denoted by `gen/from-to`.

### `/v3/minerstats`

Total reward given to each chain miner.

```
$ curl -s "https://mainnet.aeternity.io/mdw/v3/minerstats?limit=1" | jq '.'
{
  "data": [
    {
      "miner": "ak_2wkBCLxwjfcT3DHoisV7tGVQK8uni8XQwWZ6RUKD9DDwYSz8XN",
      "total_reward": 76626041292504000000
    }
  ],
  "next": "/v3/totalminers?cursor=ak_2wk52gAYRWAMi7gWP7A1oMvHEP9kpmp471VJFpvVzWMHnRc47a",
  "prev": null
}
```
---

## Activities

Intended for being able to display all events in which a specific account is related to in any way.

An activity event occurs when there's any change in the blockchain related to a specific account. It is not the same as the log events which occur when executing a contract.

### `/v3/accounts/:id/activities`

Paginated list of events related to the `:id` account.

Each activity contains 3 values:
- `height` - The height in which the event occurred
- `type` - The type of event.
- `payload` - An object whose structure depends on the type of event.

For transaction events the activity type will be `<TxType>Event`, and the payload will contain a single transaction object as displayed in the `/v3/transactions` endpoint.

Transaction events can also be `InternalContractCallEvent` which represent transactions that happen internally during a contract call.

Optionally the `owned_only=true` parameter might be used to return only activities initiated by the account.

Additionally, activities can be filtered by any of these types using `?type=<type>` query parameter:

* `transactions` - Transactions containing the account in any of the transaction fields
* `aexn` - AExN (aex9 and aex141) activities
* `aex9` - AEx9 activities
* `aex141` - AEx141 activities
* `contract` - Internal and external contract calls
* `transfers` - Internal (both gen-based and tx-based) transfers
* `claims` - Name claims related to the name hash

```
$ curl https://mainnet.aeternity.io/mdw/v3/accounts/ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx/activities
{
  "data": [
    {
      "height": 85694,
      "type": "NameUpdateTxEvent",
      "payload": {
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
          "name": "umpz.test",
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
        }
      }
    },
    {
      "payload": {
        "block_hash": "mh_2iWGwtQYYueZ8wLGTBjQ79jYfLnQKNgVcHc1GWuPqMG46UPnHY",
        "block_height": 502033,
        "hash": "th_29qxc2oEajHPVoGNS6LBe2TbKk2kyECXXR4KtbGHMhfpwdoNzD",
        "micro_index": 0,
        "micro_time": 1634367215608,
        "signatures": [
          "sg_DXk5jcdoCgGVHJUqjL2Mnu3tPxFD2mGrPga5TgVH97DZC1oq7aDZKEHgrpBqf24A4v2oBFX3zHQzXC1wj9X4ZqdzsqJqj"
        ],
        "tx": {
          "amount": 20000,
          "fee": 19320000000000,
          "nonce": 5967045,
          "payload": "ba_NTAyMDMxOmtoXzJraWtpTms0cnJnV2lNZlBLSmszU2FCdnM5TVVqdHZtNEpLeTdoVnA3Z2k5eW1uaXF1Om1oX01TZ2dxenJINlpXOW9xbmM3eXZDR1dBdGlGRGpaWGFrQWZSVndmeWtteGdWdEd3aVY6MTYzNDM2NzIxMCoV6Eo=",
          "recipient_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
          "sender_id": "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
          "ttl": 502041,
          "type": "SpendTx",
          "version": 1
        }
      },
      "type": "SpendTxEvent",
      "height": 502033
    },
    {
      "height": 659373,
      "payload": {
        "block_hash": "mh_MXVb7wmE1tqeA2xSPhTTksLy7DE5PvR8nsu5haC2fTGpgxxhR",
        "call_tx_hash": "th_Ugtejdn7SkJHXkC3VSdCm2SnXGgPxHgUphBneMqgR3gniZzDN",
        "contract_id": "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
        "contract_tx_hash": "th_6memqAr5S3UQp1pc4FWXT8xUotfdrdUFgBd8VPmjM2ZRuojTF",
        "function": "Oracle.query",
        "height": 659373,
        "internal_tx": {
          "fee": 0,
          "nonce": 0,
          "oracle_id": "ok_AFbLSrppnBFgbKPo4GykK5XEwdq15oXgosgcdL7ud6Vo2YPsH",
          "query": "YWtfcjNxRWNzWWd5Z2JjYVoxZlhQRFB0YThnZU5FUkV0OHZZaVVKNWtxQnNRNDhXVmp4NztodHRwczovL20ud2VpYm8uY24vNzc1NDY0Njg4Ny80ODE2MjEwNDI2ODYxMjg5",
          "query_fee": 20000000000000,
          "query_id": "oq_pcJy4ufijeP56LwCaJ47GcRNvJvW5nEUedR4BNeMzSobXXqMx",
          "query_ttl": {
            "type": "delta",
            "value": 20
          },
          "response_ttl": {
            "type": "delta",
            "value": 20
          },
          "sender_id": "ak_7wqP18AHzyoqymwGaqQp8G2UpzBCggYiq7CZdJiB71VUsLpR4",
          "type": "OracleQueryTx",
          "version": 1
        },
        "local_idx": 3,
        "micro_index": 0
      },
      "type": "InternalContractCallEvent"
    },
    {
      "height": 653289,
      "payload": {
        "from": "ak_11111111111111111111111111111111273Yts",
        "log_index": 0,
        "to": "ak_uTWegpfN6UjA4yz8X4ZVRi9xKEYeXHJDRZcRryTsRHAFoBpLa",
        "tx_hash": "th_2FciwUNyT7WRGee35KnNMhuoLFSCyiquVLFP3kATjwrFJh4Cfh",
        "value": 1
      },
      "type": "Aex141TransferEvent"
    }
  ],
  "next": "/v3/accounts/ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx/activities?cursor=84328-2002003-0",
  "prev": null
}
```

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

### `/websocket`

The V1 websocket interface accepts JSON - encoded commands to subscribe and unsubscribe, and answers these with the list of subscriptions. A session will look like this:

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
If it's "mdw", it indicates that it's already available through AeMdw Api.

### `/v3/websocket`

The V3 websocket interface behaves the same way as the V1 interface, but when the published message has source `mdw` it returns the rendered representation of the object as it would be rendered by the middleware (e.g. the returned object for the `Transactions` subscription will be the same object as returned by the `/v3/transactions` endpoint).

## Tests

### Unit tests

Running unit tests will not sync the database. To run them:
```
elixir --sname aeternity@localhost -S mix test
```

### Integration tests

The database has to be fully synced. Then, run the tests with:
```
elixir --sname aeternity@localhost -S mix test.integration
```

### Devmode tests

These tests allow you to create your own transactions using the devmode (plus the JS SDK). To add newer tests you need to:

1. Add the transactions creation on `node_sdk/index.js`.
2. Run the JavaScript file using `docker-compose -f docker-compose-dev.yml run node_sdk node index.js`.
3. Add new devmode tests under the `test/devmode/` directory.
4. Run tests using `./scripts/test-devmode.sh`.

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

If sure about the change, if it was for example in an integration test case and it was already tested and formatted,
one can use `git push --no-verify` to bypass the hook.

## Auto-generated Documentation

Every time an endpoint is changed, the swagger v2 file should be changed as well.
