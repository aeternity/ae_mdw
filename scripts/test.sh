#!/bin/bash

set -xe

mix local.hex --force && mix local.rebar --force && mix deps.get
rm -rf test_data.db/
elixir --sname aeternity@localhost -S mix test test/ae_mdw
exit 0
