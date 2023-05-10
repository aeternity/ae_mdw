#!/bin/bash

set -xe

mix local.hex --force && mix local.rebar --force && mix deps.get

export INTEGRATION_TEST=1
export MIX_ENV=test

elixir --sname aeternity@localhost -S mix test.devmode

exit 0
