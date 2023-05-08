NAME="aeternity@localhost"

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

  "test-integration")
    elixir --sname $NAME -S mix test.integration
    ;;

  "test")
    MIX_ENV=test elixir --sname $NAME -S mix test $2
    ;;

  "docker-sdk")
    docker-compose -f docker-compose-dev.yml run --rm node_sdk /bin/bash
esac
