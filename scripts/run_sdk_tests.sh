#!/bin/bash

set -xe

export AETERNITY_CONFIG=/home/aeternity/aeternity-dev.yaml
export IMAGE_NAME_SUFFIX=devmode

docker compose -f docker-compose-dev.yml build --build-arg MIX_ENV=prod --build-arg DEV_MODE=true ae_mdw

docker compose -f docker-compose-dev.yml up --detach ae_mdw --wait

docker compose -f docker-compose-dev.yml exec ae_mdw ./bin/ae_mdw rpc ':aeplugin_dev_mode_app.start_unlink()'

docker compose -f docker-compose-dev.yml run node_sdk /bin/sh -c "yarn install && node index.js"

docker compose -f docker-compose-dev.yml stop ae_mdw

docker compose -f docker-compose-dev.yml run --workdir=/app ae_mdw scripts/test-devmode.sh
