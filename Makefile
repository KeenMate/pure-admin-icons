# Detect operating system
ifeq ($(OS),Windows_NT)
	DETECTED_OS := Windows
	DB_GEN_CMD := db-gen-win.exe
else
	DETECTED_OS := $(shell uname -s)
	ifeq ($(DETECTED_OS),Linux)
		DB_GEN_CMD := ./db-gen-linux
	else
		$(error Unsupported operating system: $(DETECTED_OS))
	endif
endif

.PHONY: help setup deps compile build server clean clear-cache test format lint release docker-build docker-run docker-stop sync sync-fresh db-gen

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

db-gen: ## Regenerate database context from DB schema
	@echo "Generating Elixir code from PostgreSQL stored procedures..."
	@echo "Using: $(DB_GEN_CMD)"
	@if [ -f "$(DB_GEN_CMD)" ]; then \
		./$(DB_GEN_CMD) generate; \
	else \
		echo "Error: $(DB_GEN_CMD) not found. Please ensure the database code generator is available."; \
		exit 1; \
	fi
	@echo "Code generation completed."

clear-cache: ## Wipe the icon extraction cache (.cache/icons/*) so the next sync re-downloads
	@echo "Clearing icon extraction cache (.cache/icons/)..."
	@rm -rf .cache/icons
	@echo "Done. Next sync will re-download and re-extract all icon sets."

sync: ## Download and sync all icon sets (uses cache if :use_icon_cache is enabled)
	mix icons.download

sync-fresh: clear-cache sync ## Clear the cache then sync all icon sets from scratch

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
