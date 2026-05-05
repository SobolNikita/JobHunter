SHELL := /bin/bash

SERVICES := ai-service auth-service user-service resume-service job-service match-service apply-service notification-service
SERVICE ?= auth-service
SERVICE_DIR := backend/services/$(SERVICE)
IMAGE_PREFIX ?= jobhunter
IMAGE_TAG ?= dev

COMPOSE_FILE := backend/deployments/docker-compose.yml
ENV_FILE := backend/deployments/.env

.PHONY: help infra-up infra-down infra-logs infra-ps \
	service-fmt service-tidy service-build service-run \
	services-fmt services-tidy services-build services-run \
	docker-build docker-build-all docker-run

help:
	@echo "Usage:"
	@echo "  make infra-up                    # Start infra stack"
	@echo "  make infra-down                  # Stop infra stack"
	@echo "  make infra-logs                  # Tail infra logs"
	@echo "  make infra-ps                    # Show infra status"
	@echo ""
	@echo "  make service-fmt SERVICE=<name>  # gofmt one service"
	@echo "  make service-tidy SERVICE=<name> # go mod tidy one service"
	@echo "  make service-build SERVICE=<name># build one service"
	@echo "  make service-run SERVICE=<name>  # run one service locally"
	@echo ""
	@echo "  make services-fmt                # gofmt all services"
	@echo "  make services-tidy               # go mod tidy all services"
	@echo "  make services-build              # build all services"
	@echo "  make services-run                # run all services in background"
	@echo ""
	@echo "  make docker-build SERVICE=<name> # build service image"
	@echo "  make docker-build-all            # build all service images"
	@echo "  make docker-run SERVICE=<name> HOST_PORT=8081"
	@echo ""
	@echo "Available service names: $(SERVICES)"

infra-up:
	@test -f "$(ENV_FILE)" || (echo "Missing $(ENV_FILE). Copy .env.example first." && exit 1)
	docker compose -f "$(COMPOSE_FILE)" --env-file "$(ENV_FILE)" up -d

infra-down:
	docker compose -f "$(COMPOSE_FILE)" --env-file "$(ENV_FILE)" down

infra-logs:
	docker compose -f "$(COMPOSE_FILE)" --env-file "$(ENV_FILE)" logs -f

infra-ps:
	docker compose -f "$(COMPOSE_FILE)" --env-file "$(ENV_FILE)" ps

service-fmt:
	gofmt -w "$(SERVICE_DIR)/cmd/main.go"

service-tidy:
	cd "$(SERVICE_DIR)" && go mod tidy

service-build:
	cd "$(SERVICE_DIR)" && go build -o /tmp/$(SERVICE) ./cmd

service-run:
	cd "$(SERVICE_DIR)" && SERVICE_NAME="$(SERVICE)" HTTP_ADDR="$${HTTP_ADDR:-:8080}" APP_ENV="$${APP_ENV:-local}" SHUTDOWN_TIMEOUT="$${SHUTDOWN_TIMEOUT:-10s}" go run ./cmd

services-fmt:
	@for s in $(SERVICES); do \
		echo "== $$s"; \
		gofmt -w "backend/services/$$s/cmd/main.go"; \
	done

services-tidy:
	@for s in $(SERVICES); do \
		echo "== $$s"; \
		cd "backend/services/$$s" && go mod tidy; \
	done

services-build:
	@for s in $(SERVICES); do \
		echo "== $$s"; \
		cd "backend/services/$$s" && go build -o "/tmp/$$s" ./cmd; \
	done

services-run:
	@for i in $$(seq 0 $$(($(words $(SERVICES)) - 1))); do \
		s=$$(echo "$(SERVICES)" | awk "{print \$$$$(($$i + 1))}"); \
		port=$$((8081 + $$i)); \
		echo "== $$s on :$$port"; \
		nohup env SERVICE_NAME="$$s" HTTP_ADDR=":$$port" APP_ENV="$${APP_ENV:-local}" SHUTDOWN_TIMEOUT="$${SHUTDOWN_TIMEOUT:-10s}" \
			sh -c 'cd "backend/services/'"$$s"'" && go run ./cmd' >/tmp/"$$s".log 2>&1 & \
	done
	@echo "Started services. Logs: /tmp/<service>.log"

docker-build:
	docker build -t "$(IMAGE_PREFIX)/$(SERVICE):$(IMAGE_TAG)" "$(SERVICE_DIR)"

docker-build-all:
	@for s in $(SERVICES); do \
		echo "== $$s"; \
		docker build -t "$(IMAGE_PREFIX)/$$s:$(IMAGE_TAG)" "backend/services/$$s"; \
	done

docker-run:
	@test -n "$(HOST_PORT)" || (echo "Set HOST_PORT, e.g. make docker-run SERVICE=auth-service HOST_PORT=8081" && exit 1)
	docker run --rm \
		-p "$(HOST_PORT):8080" \
		-e SERVICE_NAME="$(SERVICE)" \
		-e APP_ENV="$${APP_ENV:-local}" \
		-e HTTP_ADDR=":8080" \
		-e SHUTDOWN_TIMEOUT="$${SHUTDOWN_TIMEOUT:-10s}" \
		"$(IMAGE_PREFIX)/$(SERVICE):$(IMAGE_TAG)"
