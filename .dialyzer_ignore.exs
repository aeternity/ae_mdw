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
  ~r{graphql/resolvers/contract_resolver\.ex:\d+:call\b}
]
