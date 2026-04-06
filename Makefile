.PHONY: help setup deps compile build server clean test format lint release docker-build docker-run docker-stop sync

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Install dependencies and set up the project
	mix local.hex --force
	mix local.rebar --force
	mix deps.get

deps: ## Get dependencies
	mix deps.get

compile: ## Compile the project
	mix compile

build: ## Build assets
	mix assets.deploy

server: ## Start Phoenix server
	mix phx.server

dev: ## Start Phoenix server in development mode
	iex -S mix phx.server

clean: ## Clean build artifacts
	mix clean
	rm -rf _build
	rm -rf deps
	rm -rf priv/static/assets

test: ## Run tests
	mix test

format: ## Format code
	mix format

lint: ## Check code formatting
	mix format --check-formatted

release: ## Build production release
	MIX_ENV=prod mix do compile, assets.deploy, release

sync: ## Download and sync all icon sets
	mix icons.download

docker-build: ## Build Docker image
	docker build -t pure-admin-icons:latest .

docker-run: ## Run Docker container
	docker run -d --name pure-admin-icons -p 8888:8888 \
		-e SECRET_KEY_BASE=$$(mix phx.gen.secret) \
		-e DB_USERNAME=pure_admin_icons \
		-e DB_PASSWORD=pure_admin_icons \
		-e DB_HOSTNAME=host.docker.internal \
		-e DB_DATABASE=pure_admin_icons \
		-e PHX_HOST=icons.pureadmin.io \
		pure-admin-icons:latest

docker-stop: ## Stop Docker container
	docker stop pure-admin-icons && docker rm pure-admin-icons

.DEFAULT_GOAL := help
