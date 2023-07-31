#!/bin/bash

set -xe

mix local.hex --force && mix local.rebar --force && mix deps.get
mkdir /home/aeternity/node/local/rel/aeternity/data/aecore/.iris/
cp docker/test_contracts.json /home/aeternity/node/local/rel/aeternity/data/aecore/.iris/ae_mainnet_contracts.json
elixir --sname aeternity@localhost -S mix test test/ae_mdw
exit 0
