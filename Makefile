.POSIX:

mix := mix
elixir := elixir
name := aeternity@localhost

all: help

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
compile: ## Compile backend & frontend
	$(MAKE) compile-backend && $(MAKE) compile-frontend

.PHONY: compile-backend
compile-backend: ## Compile backend only
	$(mix) deps.get && $(mix) compile

.PHONY: compile-frontend
compile-frontend: ## Compile frontend only
	cd frontend/ && npm install && npm run generate

.PHONY: clean
clean: ## Clean all artifacts
	$(MAKE) clean-backend && $(MAKE) clean-frontend

.PHONY: clean-backend
clean-backend: ## Clean backend artifacts
	$(mix) clean
	rm -rf \
	_build \
	deps \
	mix.lock

.PHONY: clean-frontend
clean-frontend: ## Clean frontend artifacts
	rm -rf ./priv/static/frontend/

.PHONY: test
test:
	$(elixir) --sname $(name) -S $(mix) test

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
