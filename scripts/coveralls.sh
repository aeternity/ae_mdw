#!/bin/bash

set -xe

MIX_ENV=test elixir --sname aeternity@localhost -S mix coveralls.github

exit 0
