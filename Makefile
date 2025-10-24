# ---------- config ----------
COMPOSE ?= docker compose
FILE    ?= docker-compose.yml       # override: make up FILE=prod.yml
PROJECT ?= tea-comm                 # override: make up PROJECT=myproj

DC = $(COMPOSE) -p $(PROJECT) -f $(FILE)

# Services to scale to 3 on startup (edit if needed)
APP_SERVICES ?= pad-booking pad-checkin user-app notif-app lostnfound_app budgeting_app fundraising-app sharing-app comm-app tea-app

# Gateway + base URL for smoke tests
GATEWAY ?= gateway
BASE    ?= http://localhost:3025
SMOKE_PATHS ?= /booking/health /checkin/health /users/health /notification/health /lostAndFound/health /budgeting/health /fundRaising/health /sharing/health /communication/health /teaManagement/health

.DEFAULT_GOAL := help

# ---------- lifecycle ----------
.PHONY: up down destroy restart pull ps logs
up:              ## Start all services and scale app services to 3 replicas
	$(DC) up -d $(foreach s,$(APP_SERVICES),--scale $(s)=3)

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

# ---------- shells & utils ----------
.PHONY: sh sh/gw restart/gw smoke print
sh:              ## Shell into a running service: make sh S=comm-app
	@test -n "$(S)" || (echo "Usage: make sh S=<service>"; exit 2)
	$(DC) exec -it $(S) sh

sh/gw:           ## Shell into the gateway container
	$(DC) exec -it $(GATEWAY) sh

restart/gw:      ## Restart the gateway container
	$(DC) restart $(GATEWAY)

smoke:           ## Simple HTTP smoke test against the gateway (200s expected)
	@command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 2; }
	@for p in $(SMOKE_PATHS); do \
		printf "GET $(BASE)$$p -> "; \
		curl -s -o /dev/null -w "%{http_code}\n" "$(BASE)$$p" || true; \
	done

print:           ## Print effective variables
	@echo "PROJECT=$(PROJECT)"
	@echo "FILE=$(FILE)"
	@echo "APP_SERVICES=$(APP_SERVICES)"
	@echo "GATEWAY=$(GATEWAY)"
	@echo "BASE=$(BASE)"

# ---------- info ----------
.PHONY: help
help:            ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<TARGET>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z0-9_\/-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
	/^$$/ {print ""}' $(MAKEFILE_LIST)
