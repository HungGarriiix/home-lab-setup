## This Makefile is used to setup home lab services
## Not running other containers/services that are not part of the core.
## Note:
##  - If this Makefile has error "Makefile:28: *** missing separator.  Stop.", please run:
##      ```
##      sed -i 's/^    /\t/' Makefile
##      ```

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

## App configs:
UI_YAML := $(ROOT_DIR)/compose.yaml
ENV_FILE := $(ROOT_DIR)/.env
ENV_EXAMPLE := $(ROOT_DIR)/.env.example

.PHONY: install
install: ## Install prerequisites
	docker --version

.PHONY: os-check
os-check: ## Check for Linux OS
	@if [ "$(shell uname -s)" != "Linux" ]; then \
	    echo "This Makefile is intended to be run on Linux."; \
	    exit 1; \
	fi

.PHONY: env-init
env-init: os-check ## Create .env from .env.example if missing
	@if [ -f $(ENV_FILE) ]; then \
	    echo ".env already exists, skipping"; \
	else \
	    cp $(ENV_EXAMPLE) $(ENV_FILE); \
	    echo "Created .env from .env.example - edit VOLUMES_DIR before running 'make run'"; \
	fi

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: run
run: os-check ## Run core services
	@echo "Running core services..."
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) up -d

.PHONY: stop
stop: os-check ## Stop core services
	@echo "Stopping core services..."
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) down

.PHONY: restart
restart: os-check ## Restart core services (keeps data)
	@echo "Restarting core services..."
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) down
	@$(MAKE) run

.PHONY: restart-hard
restart-hard: os-check ## Restart core services (removes data)
	@echo "Restarting core services (removing data)..."
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) down -v
	@$(MAKE) run

.PHONY: status
status: os-check ## Show status of core services
	@echo "Core services status:"
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) ps

.PHONY: logs
logs: os-check ## Show logs of core services
	@echo "Core services logs:"
	@docker compose --env-file $(ENV_FILE) -f $(UI_YAML) logs -f