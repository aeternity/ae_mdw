[
  # The "does not exist" warning happens because of all of the functions
  # created during runtime that belong to the AE core code.
  ~r/does not exist/,
  # Following warnings are due to bad implementation of riverside.
  {"lib/phoenix/router.ex", :pattern_match, 402},
  {"lib/riverside.ex", :pattern_match, 876},
  {"lib/ae_mdw/db/sync/transaction.ex", :pattern_match, 138},
  {"lib/ae_mdw_web/websocket/socket_handler.ex", :overlapping_contract, 2}
]
