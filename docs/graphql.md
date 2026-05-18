# GraphQL API

This middleware exposes a full-featured GraphQL API powered by Absinthe.
It runs alongside the existing REST endpoints and provides a typed, queryable
interface to blocks, transactions, accounts, names, tokens (AEX-9 and AEX-141),
channels, oracles, stats, DEX swaps, transfers, wealth, and system status.

## Endpoints

| Path | Purpose |
|------|---------|
| `/graphql` | HTTP query endpoint (always available) |
| `/graphiql` | Interactive Playground UI (opt-in via `GRAPHIQL_ENABLED`) |

Example base URL in local dev: `http://localhost:4000/graphql`

All requests use `POST`. Two content types are accepted:

```
Content-Type: application/json
Content-Type: application/x-www-form-urlencoded
```

The schema is organized by domain (accounts, blocks, transactions, contracts,
names, tokens, channels, oracles, stats, DEX swaps, transfers, wealth, status).
Use the interactive GraphiQL Playground at `/graphiql` or generate static HTML
docs with SpectaQL (see section below) for exhaustive field-level docs.

## Scalar types

| Scalar | Description |
|--------|-------------|
| `BigInt` | Arbitrary-precision integer. Serialized as a **JSON string** to avoid JavaScript `Number.MAX_SAFE_INTEGER` precision loss (e.g. `"12345678901234567890"`). Use `BigInt(value)` or an arbitrary-precision library on the client. Accepts integer literals and numeric strings as input. |
| `JSON`   | Arbitrary JSON value — used for heterogeneous map fields such as transaction `tx`, name pointers, and auction data. |

## Pagination

Most list queries return a page object with the shape:

```graphql
{
  data: [T]        # the items for this page
  prevCursor: String
  nextCursor: String
}
```

### Pagination arguments

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `cursor` | `String` | — | Opaque cursor from a previous response |
| `limit` | `Int` | 10 | Items per page. Clamped to 1–100. |
| `direction` | `Direction` | `BACKWARD` | `FORWARD` or `BACKWARD` through the data set |
| `fromHeight` | `Int` | — | (scope queries only) lower generation bound |
| `toHeight` | `Int` | — | (scope queries only) upper generation bound |

The `fromHeight` / `toHeight` arguments are available on queries that support
height-scoped pagination (transactions, transfers, block-level queries).

### Tips

- Pass `nextCursor` as `cursor` to advance forward through pages.
- Omit `cursor` to start from the most recent data.
- Combine `fromHeight`/`toHeight` with `direction: FORWARD` for
  chronological range scans.

## Query reference

### Accounts

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `account` | `id` | — | Single account by public key |
| `accountActivities` | `id` | `type`, `ownedOnly`, pagination | Activity stream for an account |

`type` enum: `transactions`, `aexn`, `aex9`, `aex141`, `contract`, `transfers`, `claims`, `swaps`.

### Blocks

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `keyBlocks` | — | pagination | Paginated list of key blocks |
| `keyBlock` | `id` | — | Key block by height or hash |
| `keyBlockAtHeight` | `height` | — | Key block at an exact height |
| `keyBlockWithHash` | `hash` | — | Key block with a specific hash |
| `keyBlockMicroBlocks` | `id` | pagination | Micro blocks of a key block by height or hash |
| `microBlocksOfKeyBlockAtHeight` | `height` | pagination | Micro blocks by key-block height |
| `microBlocksOfKeyBlockWithHash` | `hash` | pagination | Micro blocks by key-block hash |
| `microBlock` | `hash` | — | Single micro block by hash |

### Transactions

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `transaction` | `hash` or `id` | — | Single transaction |
| `transactions` | — | `type`, `typeGroup`, `account`, `contract`, `channel`, `oracle`, `senderId`, `recipientId`, `entrypoint`, pagination | Filtered transactions |
| `transactionsCount` | — | `type`, `typeGroup`, `id` | Count of transactions matching filters |
| `microBlockTransactions` | `hash` | pagination | Transactions from a micro block |
| `pendingTransactions` | — | `type`, pagination | Transactions in the mempool |
| `pendingTransactionsCount` | — | — | Number of pending transactions |
| `accountTransactionsCount` | `id` | `type`, `typeGroup` | Per-type tx counts for an account (returns JSON) |

### Names

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `name` | `id` | — | Name or auction by plain name / name hash |
| `names` | — | `ownedBy`, `prefix`, `state`, `orderBy`, pagination | Filtered name list |
| `searchNames` | `prefix` | `ownedBy`, pagination | Names matching a prefix |
| `namesCount` | — | `ownedBy` | Count of names |
| `nameClaims` | `id` | pagination | Claim history for a name |
| `nameUpdates` | `id` | pagination | Update history for a name |
| `nameTransfers` | `id` | pagination | Transfer history for a name |
| `nameHistory` | `id` | pagination | Full event history for a name |
| `auction` | `id` | — | Single active auction |
| `auctions` | — | `orderBy`, pagination | Paginated list of auctions |
| `auctionClaims` | `id` | pagination | Claim bids for an auction |
| `accountNameClaims` | `accountId` | pagination | All names claimed by an account |
| `accountNamePointees` | `accountId` | pagination | Names pointing to an account |

`state` enum: `active`, `inactive`.
`orderBy` (names) enum: `expiration`, `activation`, `deactivation`, `name`.
`orderBy` (auctions) enum: `expiration`, `name`.

### AEX-9 (Fungible tokens)

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `aex9Count` | — | — | Total number of AEX-9 contracts |
| `aex9Contracts` | — | `orderBy`, `prefix`, `exact`, pagination | List of AEX-9 contracts |
| `aex9Contract` | `id` | — | Single AEX-9 contract by id |
| `aex9ContractBalances` | `id` | `orderBy`, `blockHash`, pagination | All token balances within a contract |
| `aex9BalanceHistory` | `contractId`, `accountId` | pagination | Balance history for one account |
| `aex9TokenBalance` | `contractId`, `accountId` | `hash` | Balance of one account at a block |
| `aex9AccountBalances` | `accountId` | pagination | All AEX-9 balances for an account |
| `aex9ContractTransfers` | `contractId` | `sender`, `recipient`, `account`, pagination | Transfers within a contract |

`orderBy` (contracts) enum: `creation`, `name`, `symbol`.
`orderBy` (balances) enum: `pubkey`, `amount`.

### AEX-141 (NFTs)

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `aex141Count` | — | — | Total number of AEX-141 contracts |
| `aex141Contracts` | — | `orderBy`, `prefix`, `exact`, pagination | List of AEX-141 contracts |
| `aex141Contract` | `id` | — | Single AEX-141 contract by id |
| `aex141Transfers` | — | `from`, `to`, pagination | All AEX-141 transfers |
| `aex141ContractTransfers` | `contractId` | `from`, `to`, pagination | Transfers for a specific NFT contract |
| `aex141ContractTokens` | `contractId` | pagination | All tokens in a contract |
| `aex141ContractToken` | `contractId`, `tokenId` | — | Single token info and metadata |
| `aex141AccountTokens` | `accountId` | `contract`, pagination | All NFTs owned by an account |
| `aex141ContractTemplates` | `contractId` | pagination | Templates in an AEX-141 contract |
| `aex141ContractTemplateTokens` | `contractId`, `templateId` | pagination | Tokens for a specific template |

`orderBy` enum: `creation`, `name`, `symbol`.

### Channels

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `channels` | — | `state`, pagination | Paginated list of channels |
| `channel` | `id` | — | Single channel by id |
| `channelUpdates` | `id` | pagination | Update history for a channel |

`state` enum: `active`, `inactive`.

### Contracts

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `contracts` | — | pagination | Paginated list of contracts |
| `contract` | `id` | — | Single contract by id |
| `contractsLogs` | — | `contractId`, `event`, `data`, `aexnArgs`, pagination | Logs across all contracts |
| `contractLogs` | `id` | `event`, `data`, `aexnArgs`, pagination | Logs for a specific contract |
| `contractsCalls` | — | `function`, `functionPrefix`, `aexnArgs`, pagination | Calls across all contracts |
| `contractCalls` | `id` | `function`, `functionPrefix`, `aexnArgs`, pagination | Calls for a specific contract |

### Oracles

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `oracles` | — | `state`, pagination | Paginated list of oracles |
| `oracle` | `id` | — | Single oracle by public key |
| `oracleQueries` | `id` | pagination | Queries submitted to an oracle |
| `oracleResponses` | `id` | pagination | Responses from an oracle |
| `oracleExtends` | `id` | pagination | Extend transactions for an oracle |

`state` enum: `active`, `inactive`.

### DEX

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `swaps` | — | `tokenSymbol`, pagination | All DEX swaps |
| `accountSwaps` | `accountId` | `tokenSymbol`, pagination | Swaps for a specific account |
| `contractSwaps` | `contractId` | `tokenSymbol`, pagination | Swaps for a specific DEX contract |

### Transfers

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `transfers` | — | `account`, `kind`, pagination | AE + token transfers |

### Wealth

| Query | Required args | Optional args | Description |
|-------|---------------|---------------|-------------|
| `wealth` | — | pagination | Top accounts by AE balance |

### Stats

All time-series stats queries accept `intervalBy` (`day`, `week`, `month`),
`minStartDate`, and `maxStartDate` (ISO-8601 date strings) unless noted.

| Query | Extra args | Description |
|-------|------------|-------------|
| `stats` | — | Global counters (txs, blocks, contracts, names, …) |
| `transactionsStats` | `txType` | Tx count over time |
| `totalTransactionsStats` | `txType`, dates | Cumulative tx count |
| `blocksStats` | `type` (`key`/`micro`) | Block count over time |
| `difficultyStats` | — | Mining difficulty over time |
| `hashrateStats` | — | Hash rate over time |
| `totalAccountsStats` | — | Total account count over time |
| `activeAccountsStats` | — | Active account count over time |
| `namesStats` | — | Name count over time |
| `contractsStats` | — | Contract count over time |
| `aex9TransfersStats` | — | AEX-9 transfer count over time |
| `totalStats` | pagination | Per-generation stats from chain tip |
| `deltaStats` | pagination | Aggregated delta stats from chain tip |
| `minersStats` | pagination | Total rewards per miner |
| `topMinersStats` | pagination | Top miners by reward |
| `topMiners24hStats` | pagination | Top miners in the last 24 hours |

### Status

| Query | Description |
|-------|-------------|
| `status` | Middleware and node health, sync progress |
| `syncStatus` | Sync state details |

## Example queries

### Blocks

Fetch the 3 most recent key blocks:

```graphql
query {
  keyBlocks(limit: 3) {
    data { height hash time miner transactionsCount }
    nextCursor
  }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query {
  keyBlocks(limit: 3) {
    data { height hash time miner transactionsCount }
    nextCursor
  }
}'
```

Fetch micro blocks of a key block by height:

```graphql
query($height: Int!) {
  microBlocksOfKeyBlockAtHeight(height: $height, limit: 5) {
    data { microBlockIndex hash time gas transactionsCount }
  }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query($height: Int!) {
  microBlocksOfKeyBlockAtHeight(height: $height, limit: 5) {
    data { microBlockIndex hash time gas transactionsCount }
  }
}' \
  --data-urlencode 'variables={"height":100000}'
```

### Transactions

Single transaction by hash:

```graphql
query($hash: String!) {
  transaction(hash: $hash) {
    hash blockHash type txIndex
  }
}
```

Filter transactions by type and account:

```graphql
query($types: [String!], $account: String) {
  transactions(type: $types, account: $account, limit: 10) {
    data { hash type blockHash }
    nextCursor
  }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query($types: [String!], $account: String) {
  transactions(type: $types, account: $account, limit: 10) {
    data { hash type blockHash }
    nextCursor
  }
}' \
  --data-urlencode 'variables={"types":["SpendTx"],"account":"ak_2a...YOUR_ACCOUNT..."}'
```

### Names

Get a name by plain name or name hash:

```graphql
query { name(id: "support.chain") { name active ownership expireHeight } }
```

Search names by prefix:

```graphql
query {
  searchNames(prefix: "ae") {
    data { name active expireHeight }
    nextCursor
  }
}
```

List active names ordered by expiration:

```graphql
query {
  names(state: active, orderBy: expiration, direction: FORWARD, limit: 10) {
    data { name expireHeight ownership }
    nextCursor
  }
}
```

Full name history:

```graphql
query($name: String!) {
  nameHistory(id: $name) {
    data { type height blockHash }
  }
}
```

List names owned by an account:

```graphql
query($owner: String!) {
  names(ownedBy: $owner, limit: 10) {
    data { name active expireHeight }
  }
}
```

### AEX-9 (Fungible tokens)

Token info by contract:

```graphql
query($id: String!) {
  aex9Contract(id: $id) { symbol name decimals }
}
```

All balances in a contract, ordered by amount (largest first):

```graphql
query($id: String!) {
  aex9ContractBalances(id: $id, orderBy: amount, direction: BACKWARD, limit: 10) {
    data { accountId balance }
    nextCursor
  }
}
```

All AEX-9 balances for an account across all contracts:

```graphql
query($account: String!) {
  aex9AccountBalances(accountId: $account, limit: 20) {
    data { contractId accountId balance }
    nextCursor
  }
}
```

### AEX-141 (NFTs)

Contract info and a single token:

```graphql
query($id: String!, $tokenId: String!) {
  aex141Contract(id: $id) { name symbol }
  aex141ContractToken(contractId: $id, tokenId: $tokenId) {
    tokenId contractId owner metadata
  }
}
```

All NFTs owned by an account:

```graphql
query($account: String!) {
  aex141AccountTokens(accountId: $account, limit: 20) {
    data { contractId tokenId owner }
    nextCursor
  }
}
```

### Accounts

Account with balance:

```graphql
query($id: String!) {
  account(id: $id) { id balance creationTime }
}
```

Account activities filtered by type:

```graphql
query($id: String!) {
  accountActivities(id: $id, type: transactions, limit: 20) {
    data { type height blockHash payload blockTime }
  }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query($id: String!) {
  accountActivities(id: $id, type: transactions, limit: 20) {
    data { type height blockHash payload blockTime }
  }
}' \
  --data-urlencode 'variables={"id":"ak_2a...YOUR_ACCOUNT..."}'
```

### Contracts

Contract call list filtered by function name:

```graphql
query($id: String!) {
  contractCalls(id: $id, function: "transfer", limit: 10) {
    data { callTxHash function arguments height }
    nextCursor
  }
}
```

Contract log list with event filter:

```graphql
query($id: String!) {
  contractLogs(id: $id, event: "Transfer", limit: 10) {
    data { callTxHash eventHash args height }
    nextCursor
  }
}
```

### Oracles

```graphql
query($id: String!) {
  oracle(id: $id) { id queryFee ttl }
  oracleQueries(id: $id, limit: 5) { data { id query blockHash } }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query($id: String!) {
  oracle(id: $id) { id queryFee ttl }
  oracleQueries(id: $id, limit: 5) { data { id query blockHash } }
}' \
  --data-urlencode 'variables={"id":"ok_2o...YOUR_ORACLE..."}'
```

### Channels

```graphql
query($id: String!) {
  channel(id: $id) { id state }
  channelUpdates(id: $id, limit: 10) { data { type height } }
}
```

```bash
curl -sS http://localhost:4000/graphql \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'query=query($id: String!) {
  channel(id: $id) { id state }
  channelUpdates(id: $id, limit: 10) { data { type height } }
}' \
  --data-urlencode 'variables={"id":"ch_2v...YOUR_CHANNEL..."}'
```

### DEX swaps

All swaps for an account:

```graphql
query($account: String!) {
  accountSwaps(accountId: $account, limit: 10) {
    data { txHash amountIn amountOut tokenIn tokenOut }
  }
}
```

### Transfers (AE + tokens)

```graphql
query($account: String) {
  transfers(account: $account, limit: 10) {
    data { kind amount sender recipient height }
  }
}
```

### Wealth distribution

Top 10 accounts by AE balance:

```graphql
query {
  wealth(limit: 10) {
    data { accountId balance rank }
    nextCursor
  }
}
```

### Stats

Daily transaction count for the last 7 days:

```graphql
query {
  transactionsStats(intervalBy: day, limit: 7) {
    data { startDate endDate count }
  }
}
```

Global counters:

```graphql
query {
  stats { height txsCount contractsCount namesCount }
}
```

### Status / health

```graphql
query {
  status { network mdwHeight nodeHeight syncProgress }
  syncStatus { synced syncing }
}
```

## Error handling

GraphQL errors are returned with HTTP 200 per the GraphQL specification.
Inspect the `errors` array in the response:

```json
{
  "data": null,
  "errors": [
    {
      "message": "not found",
      "locations": [{ "line": 2, "column": 3 }],
      "path": ["account"]
    }
  ]
}
```

Common error messages:

| Message | Cause |
|---------|-------|
| `"not found"` | The requested resource does not exist |
| `"partial_state_unavailable"` | Node is still syncing; result set is incomplete |
| `"Operation complexity exceeds limit"` | Query is too expensive; reduce `limit` or request fewer fields |

## Performance and complexity

The server enforces a **complexity limit** (default 1 000, configurable via
`GRAPHQL_MAX_COMPLEXITY`). Complexity is calculated as:

```
complexity = limit × child_field_complexity + 1
```

for each list field with pagination args. If a query exceeds the limit, the
server rejects it before execution.

**Tips:**
- Reduce `limit` when selecting many nested fields.
- Use field selection to request only what you need.
- Prefer specific ID lookups (`account`, `transaction`) over broad list queries
  when you already know the identifier.

Successful query responses are cached in ETS for a configurable TTL
(`GRAPHQL_RESPONSE_CACHE_TTL_MS`, default 5 000 ms). Set to `0` to disable.

## Using the Playground

Open `/graphiql` in a browser. The Playground supports:

- Query history and variable editing
- Schema introspection via the Docs panel
- Auto-complete

The playground is disabled by default in every environment. Enable it by
setting the environment variable:

```bash
GRAPHIQL_ENABLED=true
```

The check is at request time, so it can be toggled on a running node without
a redeploy — useful when running multiple instances behind a load balancer and
exposing the playground on only one of them.

### Running GraphiQL on a production node

The route is always mounted; only the `GRAPHIQL_ENABLED` flag controls whether
it serves the UI or a 404. Enabling it on a production node is low-risk because:

- The MDW REST API is already fully public — the schema adds no new attack
  surface that could not be discovered via a plain introspection POST to
  `/graphql`.
- The complexity limiter (`GRAPHQL_MAX_COMPLEXITY`, default 1000) and the
  response-cache TTL (`GRAPHQL_RESPONSE_CACHE_TTL_MS`) already protect
  against expensive interactive queries.

Considerations if you do enable it:

- Schema introspection is enabled automatically; it can be disabled in
  Absinthe if you need to harden the endpoint.
- The playground loads ~1 MB of JavaScript assets from the server, so traffic
  overhead is per-browser-session only, not per API request.
- Make sure your CORS and reverse-proxy rules are intentional — the playground
  issues POST requests from the browser origin.

## Generating static docs

This repo includes a SpectaQL config under
`docs/graphql_doc_gen/spectaql-config.yml`. To generate static HTML docs
locally:

1. Ensure the MDW is running locally.
2. Navigate to `docs/graphql_doc_gen` and run `docker compose up`.
3. The generated docs will be available at `http://localhost:4400`.

```bash
# from the repo root
cd docs/graphql_doc_gen
docker compose up
```

The auto-generated docs include the exhaustive field list for every type and
stay authoritative; this file covers usage patterns and environment-specific
configuration.

## Notes

- **Authentication**: The GraphQL API is public like the REST API; rate-limiting
  or auth can be added behind a reverse proxy if needed.
- **CORS**: Configure CORS at the gateway if you expose the API cross-origin.
- **WebSocket / subscriptions**: The current implementation does not expose
  GraphQL subscriptions. Real-time updates are available via the WebSocket API.
