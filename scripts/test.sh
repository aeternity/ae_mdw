#!/bin/bash

set -xe

mix local.hex --force && mix local.rebar --force && mix deps.get
elixir --sname aeternity@localhost -S mix test

exit 0
