#!/bin/bash

set -xe

docker-compose -f docker-compose-dev.yml build --build-arg DEV_MODE=true ae_mdw

export AETERNITY_CONFIG=/home/aeternity/aeternity-dev.yaml

docker-compose -f docker-compose-dev.yml up --detach ae_mdw

sleep 10

docker-compose -f docker-compose-dev.yml exec ae_mdw ./bin/ae_mdw rpc ':aeplugin_dev_mode_app.start_unlink()'

docker-compose -f docker-compose-dev.yml run node_sdk node index.js

docker-compose -f docker-compose-dev.yml stop ae_mdw

docker-compose -f docker-compose-dev.yml run --workdir=/app ae_mdw elixir --sname aeternity@localhost -S mix test.devmode
