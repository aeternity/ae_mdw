#!/bin/bash

set -xe

export INTEGRATION_TEST=1
export MIX_ENV=test

mix local.hex --force && mix local.rebar --force && mix deps.get

elixir --sname aeternity@localhost -S mix test.devmode

exit 0
