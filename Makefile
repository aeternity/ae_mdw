.POSIX:

mix := mix
elixir := elixir
name := aeternity@localhost

all: help

.PHONY: deps
deps: ## Get and compile Elixir dependencies
	$(mix) deps.get \
	$(mix) compile

.PHONY: compile
compile: ## Compile Elixir code
	$(mix) compile && $(MAKE) compile-frontend

.PHONY: reset-mdw-db
reset-mdw-db: ## Reset Middleware DB tables
	$(mix) reset_db

.PHONY: shell
shell: ## Launch a mix shell with all modules compiled and loaded
	iex --sname $(name) -S $(mix) phx.server

.PHONY: format
format: ## Format Elixir code
	$(mix) format

.PHONY: generate-frontend
compile-frontend: ## Generate frontend only
	cd frontend/ && npm run generate


.PHONY: clean-frontend
clean-frontend: ## Clean frontend artifacts
	rm -rf ./priv/static/frontend/

.PHONY: clean
clean: ## Clean all artifacts
	$(mix) clean
	rm -rf \
		_build \
		deps \
		mix.lock

.PHONY: test
test:
	$(elixir) --sname $(name) -S $(mix) test

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
