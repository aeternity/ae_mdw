#!/bin/bash

set -xe
MIX_ENV=test
mix local.hex --force && mix local.rebar --force && mix deps.get
rm -rf test_data.db/
elixir --sname aeternity@localhost -S mix test $1
exit 0
