NAME="aeternity@localhost"

case $1 in
  "shell")
    iex --sname $NAME -S mix phx.server
    ;;

  "remsh")
    iex --sname console --remsh $NAME
    ;;

  "docker-shell")
    docker-compose run --rm --workdir=/app --entrypoint="" ae_mdw /bin/bash
    ;;

  "test-integration")
    elixir --sname $NAME -S mix test.integration
    ;;

  "test")
    elixir --sname $NAME -S mix test
    ;;
esac
