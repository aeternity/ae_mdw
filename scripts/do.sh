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

  "remsh")
    iex --sname console --remsh $NAME
    ;;

  "docker-shell")
    docker-compose -f docker-compose-dev.yml run --rm --workdir=/app --entrypoint="" --use-aliases --service-ports ae_mdw /bin/bash
    ;;

  "testnet-docker-shell")
    maybe_create_db_directory "./data_testnet"
    docker-compose -f docker-compose-dev-testnet.yml run --rm --workdir=/app --entrypoint="" --use-aliases --service-ports ae_mdw_testnet /bin/bash
    ;;

  "test-integration")
    elixir --sname $NAME -S mix test.integration $2
    ;;

  "test")
    rm -rf test_data.db
    MIX_ENV=test elixir --sname $NAME -S mix test $2
    ;;

  "docker-sdk")
    docker-compose -f docker-compose-dev.yml run --rm node_sdk /bin/bash
esac
