.POSIX:

mix := mix
elixir := elixir
name := aeternity@localhost

all: help

.PHONY: deps
deps: ## Get and compile Elixir dependencies
	$(mix) deps.get

.PHONY: all-deps
all-deps: sophia-dep deps

.PHONY: ae-local-dir
ae-local-dir: ## puts Aeternity's node local dir location from config.exs to AE_LOCAL_DIR
	$(eval AE_LOCAL_DIR=$(shell elixir -e "Application.ensure_started(:mix); xxx = Mix.Config.eval!(\"config/config.exs\"); get_in(elem(xxx, 0), [:ae_plugin, :node_root]) |> Path.absname |> Path.expand |> IO.puts"))

.PHONY: sophia-dep
sophia-dep: ae-local-dir ## Clones aesophia and fixes its build instructions
	$(shell \
	test -d deps || mkdir deps; \
	test -d deps/aesophia || git clone https://github.com/aeternity/aesophia.git deps/aesophia; \
	rm -f deps/aesophia/rebar*; \
	(printf 'compile:\n'; \
	printf '	test -d ebin || mkdir ebin\n'; \
	printf '	erlc -o ebin -I %q/lib/ src/*.erl\n' $(AE_LOCAL_DIR); \
	printf '	test -d ebin/aesophia.app || cp src/aesophia.app.src ebin/aesophia.app\n') > deps/aesophia/Makefile;)

.PHONY: reset-mdw-db
reset-mdw-db: ## Reset Middleware DB tables
	$(mix) reset_db

.PHONY: shell
shell: ## Launch a mix shell with all modules compiled and loaded
	iex --sname $(name) -S $(mix) phx.server

.PHONY: format
format: ## Format Elixir code
	$(mix) format

.PHONY: compile
compile: ## Compile backend
	$(MAKE) compile-backend

.PHONY: compile-backend
compile-backend: ## Compile backend only
	$(mix) deps.get && $(mix) compile

.PHONY: clean
clean: ## Clean all artifacts
	$(MAKE) clean-backend

.PHONY: clean-backend
clean-backend: ## Clean backend artifacts
	$(mix) clean
	rm -rf \
	_build \
	deps \
	REVISION \
	VERSION \
	mix.lock

.PHONY: test
test:
	$(elixir) --sname $(name) -S $(mix) test

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
