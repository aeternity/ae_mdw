[
  # The "does not exist" warning happens because of all of the functions
  # created during runtime that belong to the AE core code.
  ~r/does not exist/,

  # GraphQL resolvers extract AeMdw.Db.State.t() from Absinthe's context map.
  # Absinthe.Resolution.context is typed as `map()`, so dialyzer cannot track
  # the opaque type through it and emits call_without_opaque + derived no_return
  # for every resolver function that calls a domain API with state.
  # These are all false positives — the runtime value is always a valid State.t().
  ~r{graphql/resolvers/.+:call_without_opaque},
  ~r{graphql/resolvers/.+:no_return},

  # contract_resolver.ex: the same opaque-type loss causes dialyzer to type state
  # as `any()`, which then also fails the positional contract check (:call warning).
  ~r{graphql/resolvers/contract_resolver\.ex:\d+:call\b},

  # blocks.ex: sparse-state fixtures store Model.block rows with hash: nil even
  # though Blocks.block_hash() is typed as <<_::256>>. The nil-hash clause in
  # render_key_block/2 is a deliberate runtime guard, not an unreachable pattern.
  ~r{lib/ae_mdw/blocks\.ex:\d+:pattern_match},

  # fix_aex9_nested_creation_double_counted_balances.ex: dialyzer infers the
  # Aex9Balances.get_balances/2 dry-run call can never return {:ok, _, _} here,
  # even though the identical call succeeds elsewhere (aexn_create_contract_mutation.ex).
  # A false positive, not a real unreachable path.
  ~r{fix_aex9_nested_creation_double_counted_balances\.ex},

  # recompute_all_aex9_balances_from_dry_run.ex: same false positive as above,
  # now for the broad migration that supersedes it.
  ~r{recompute_all_aex9_balances_from_dry_run\.ex}
]
