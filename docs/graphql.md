# GraphQL Integration (Experimental)

Status: INITIAL SKELETON (alpha). Only a single field (`contract(id)`) is exposed so far.

This document explains how to use, test, and extend the new GraphQL endpoint.

---
## Endpoints

| Path | Method | Description |
|------|--------|-------------|
| `/graphql`  | POST | Execute GraphQL operations (queries & mutations — only queries exist now). |
| `/graphiql` | GET  | Interactive GraphiQL / Playground UI (available only in non-prod Mix envs). |

Both are mounted ahead of the REST versioned routes. CORS follows the existing `:api` pipeline configuration.

### Example Query
```graphql
{
  contract(id: "ct_invalid") { id aexn_type meta_name meta_symbol }
}
```
Expected error response:
```json
{
  "errors": [ { "message": "invalid_contract_id" } ]
}
```

### Current Fields
| Field | Args | Returns | Notes |
|-------|------|---------|-------|
| `contract` | `id: ID!` | `Contract` | Fetches contract metadata; only partially populated today. |

`Contract` type fields:
- `id: ID!` (echo of provided contract pubkey)
- `aexn_type: String` (e.g. `"aex9"`, `"aex141"`, or null)
- `meta_name: String`
- `meta_symbol: String`

> Decimals, version, holders, total supply, and on-chain state are not yet exposed.

---
## Resolver Behavior & Limitations
- The resolver decodes `ct_`-prefixed contract public keys using the node encoder.
- If the ID does not look like a contract pubkey, it returns an Absinthe error with message `invalid_contract_id`.
- It tries to derive AEXN token meta info (name & symbol) when the contract type is recognized.
- It currently expects a `:state` entry in the Absinthe context (to be provided by future context plug). If absent, it may fall back to returning `missing_state` errors when more logic is added.

Planned improvements:
1. Add context bridge to inject the same chain state used by REST (so queries reflect latest sync snapshot).
2. Add batching (Dataloader) if multiple contracts are queried in one request.
3. Provide structured error extensions (e.g. `{ code, detail }`).

---
## Running Queries (Development)
1. Start the application normally (REST server + GraphQL):
   ```bash
   mix phx.server
   ```
2. Navigate to: `http://localhost:4000/graphiql`
3. Run the sample query.

If you run into node / DB ownership errors while running tests or starting the node, set a consistent Erlang node name:
```bash
elixir --name aeternity@localhost -S mix phx.server
```
Or for tests:
```bash
elixir --name aeternity@localhost -S mix test
```

> Avoid using `--sname` with an `@host` suffix; use `--name` for long names or `--sname aeternity` for short names.

---
## Testing
A minimal ExUnit test exists at:
`test/ae_mdw_web/graphql/contract_query_test.exs`

It currently checks error handling for invalid IDs. The test spins up the full application tree which includes a heavy node startup phase.

### Making Tests Faster (Planned)
A future refactor will:
- Introduce a config flag (e.g. `config :ae_mdw, :start_node_services, false` in test) to skip aecore-related apps in unit tests.
- Provide a mock or lightweight in-memory state for resolvers.

---
## Roadmap
| Phase | Goal | Notes |
|-------|------|------|
| 1 | Basic contract query (DONE) | Skeleton online. |
| 2 | Context bridge & graceful missing state handling | Use existing StatePlug output. |
| 3 | Add account & name queries | Mirror frequently used REST endpoints. |
| 4 | Pagination & connections | Cursor-based pattern for lists (contracts, transfers). |
| 5 | Complexity & depth limits | Mitigate resource exhaustion; e.g. `max_depth: 12`. |
| 6 | Token (AEX9 / AEX141) richer fields | Supply, holders, balances (with pagination). |
| 7 | Subscriptions (optional) | Uses existing PubSub for real-time events. |
| 8 | Telemetry + structured errors | Unified metrics and improved DX. |

---
## Design Principles
- Parity-first: GraphQL fields will align with existing REST semantics before introducing novel aggregations.
- Explicit pagination: No unbounded list fields.
- Streaming / large scans avoided; use indexed / cached paths exposed by the DB layer.
- Deterministic errors: Each validation failure maps to a stable error message code.

---
## Extending the Schema
1. Add a new resolver module under `lib/ae_mdw_web/graphql/resolvers/`.
2. Define object / field additions in `AeMdwWeb.GraphQL.Schema` (or split into type modules later with `import_types`).
3. Ensure arguments are validated early; return domain errors via `{:error, code}`.
4. Add tests that do NOT rely on the full chain when possible (inject or mock state).

Example (future) field stub:
```elixir
field :account, :account do
  arg :id, non_null(:id)
  resolve &AccountResolver.account/3
end
```

---
## Security Considerations
- Depth & complexity limits are not yet enforced (add them before exposing publicly).
- Rate limiting is inherited from existing stack (none specific to GraphQL yet).
- User input is limited to IDs now; later additions must validate pagination cursors and filters.

---
## Contributing
Open a PR adding new fields and include:
- Schema changes
- Resolver(s)
- Unit tests (success + failure)
- Brief addition to this doc (Roadmap or new section)

---
## FAQ
**Why Absinthe instead of generating GraphQL from REST automatically?**  
Absinthe offers strong flexibility, custom middleware, and Elixir-native patterns for batching and instrumentation.

**Will REST be deprecated?**  
Not in the short term. GraphQL is additive and will target aggregate and selective data retrieval patterns first.

**How do I enable GraphiQL in prod for debugging?**  
You should not. If absolutely necessary, guard it behind an env flag and temporary branch only.

---
## Support / Contact
File an issue in the repository with the `graphql` label for feature requests or bugs.
