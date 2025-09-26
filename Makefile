# ---------- config ----------
COMPOSE ?= docker compose
FILE    ?= docker-compose.yml       # override: make up FILE=prod.yml
PROJECT ?= tea-comm                # override: make up PROJECT=myproj

DC = $(COMPOSE) -p $(PROJECT) -f $(FILE)

.DEFAULT_GOAL := help

# ---------- lifecycle ----------
.PHONY: up down destroy restart pull ps logs
up:              ## Start all services in the background
	$(DC) up -d

down:            ## Stop and remove containers (keep volumes)
	$(DC) down --remove-orphans

destroy:         ## Stop and remove containers + named volumes
	$(DC) down -v --remove-orphans

restart:         ## Restart all services (or one with S=service)
	@if [ -n "$(S)" ]; then $(DC) restart $(S); else $(DC) restart; fi

pull:            ## Pull all images
	$(DC) pull

ps:              ## List services
	$(DC) ps

logs:            ## Tail logs (all or S=service)
	@if [ -n "$(S)" ]; then $(DC) logs -f $(S); else $(DC) logs -f; fi

# ---------- seeds ----------
.PHONY: seed seed/tea seed/comm
seed:            ## Run both seed jobs
	$(DC) run --rm tea-seed
	$(DC) run --rm comm-seed

seed/tea:        ## Run tea seeder
	$(DC) run --rm tea-seed

seed/comm:       ## Run communication seeder
	$(DC) run --rm comm-seed

# ---------- tests ----------
.PHONY: test test/tea test/comm
test:            ## Run all tests and tear down test profile
	@set -e; \
	$(DC) --profile test up --abort-on-container-exit tea-tests comm-tests; \
	code=$$?; \
	$(DC) --profile test down --remove-orphans; \
	exit $$code

test/tea:        ## Run only tea tests
	@set -e; \
	$(DC) --profile test up --abort-on-container-exit tea-tests; \
	code=$$?; \
	$(DC) --profile test down --remove-orphans; \
	exit $$code

test/comm:       ## Run only communication tests
	@set -e; \
	$(DC) --profile test up --abort-on-container-exit comm-tests; \
	code=$$?; \
	$(DC) --profile test down --remove-orphans; \
	exit $$code

# ---------- shells & db utils ----------
.PHONY: sh psql/tea psql/comm redis/tea redis/comm
sh:              ## Shell into a running service: make sh S=comm-app
	@test -n "$(S)" || (echo "Usage: make sh S=<service>"; exit 2)
	$(DC) exec -it $(S) sh

psql/tea:        ## psql into tea-db
	$(DC) exec -it tea-db psql -U tea -d tea

psql/comm:       ## psql into comm-db
	$(DC) exec -it comm-db psql -U comm -d comm

redis/tea:       ## redis-cli into tea-redis
	$(DC) exec -it tea-redis redis-cli

redis/comm:      ## redis-cli into comm-cache
	$(DC) exec -it comm-cache redis-cli

# ---------- info ----------
.PHONY: help
help:            ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<TARGET>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z0-9_\/-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
	/^$$/ {print ""}' $(MAKEFILE_LIST)
