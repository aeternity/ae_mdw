NAME="aeternity@localhost"

maybe_create_db_directory() {
  if [[ ! -e $1 ]]; then
    while true; do
      read -p "Do you want to create the $(realpath $1) directory? [y/n] " answer
      case $answer in
        [Yy] ) mkdir $1; return 0;;
        [Nn] ) return 0;;
        * ) echo "Please answer y or n.";;
      esac
    done
  fi
}

case $1 in
  "volumes")
    mkdir -p data/mnesia data/mdw.db
    chown -R 1000 data
    ;;

  "shell")
    mix local.hex --force && mix local.rebar --force && mix deps.get
    iex --sname $NAME -S mix phx.server
    ;;

  "hc-shell")
    mix local.hex --force && mix local.rebar --force && mix deps.get
    AETERNITY_CONFIG=./hyperchain/aeternity.yaml iex --sname $NAME -S mix phx.server
    ;;


  "remsh")
    iex --sname console --remsh $NAME
    ;;

  "docker-shell")
    docker-compose -f docker-compose-dev.yml run --rm --workdir=/app --entrypoint="" --use-aliases --service-ports ae_mdw /bin/bash
    ;;

  "hc-docker-shell")
    maybe_create_db_directory "./data_hc"
    docker-compose -f docker-compose-hc.yml run --rm --workdir=/app --entrypoint="" --use-aliases --service-ports ae_mdw_hc /bin/bash
    ;;

  "testnet-docker-shell")
    maybe_create_db_directory "./data_testnet"
    docker-compose -f docker-compose-dev-testnet.yml run --rm --workdir=/app --entrypoint="" --use-aliases --service-ports ae_mdw_testnet /bin/bash
    ;;

  "test-integration")
    MIX_ENV=test INTEGRATION_TEST=1 elixir --sname aeternity@localhost -S mix test.integration $2
    ;;

  "test")
    rm -rf test_data.db
    MIX_ENV=test elixir --sname $NAME -S mix test $2
    ;;

  "docker-sdk")
    docker-compose -f docker-compose-dev.yml run --rm node_sdk /bin/bash
    ;;

  "generate-swagger")
    docker compose -f docker-compose-dev.yml up ae_mdw -d
    docker compose -f docker-compose-dev.yml exec ae_mdw bash -c "mkdir -p /app/swagger_v3; cp -f /home/aeternity/node/local/lib/aehttp-*/priv/oas3.yaml /app/swagger_v3/node_oas3.yaml"
    docker compose -f docker-compose-dev.yml cp ae_mdw:/app/swagger_v3/ docs/
    docker compose -f docker-compose-dev.yml down ae_mdw
    scripts/swagger-docs.py
    ;;
esac
