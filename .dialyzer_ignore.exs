[
  # The "does not exist" warning happens because of all of the functions
  # created during runtime that belong to the AE core code.
  ~r/does not exist/,
  # Following warnings are due to bad implementation of riverside.
  {"deps/phoenix/lib/phoenix/router.ex", :pattern_match, 405}
]
