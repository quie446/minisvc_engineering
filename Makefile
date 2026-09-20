# Single entrypoint for local/CI delivery of minisvc.
# Every target is strict: failures exit non-zero (no false green).

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Version stamping: defaults derive from git, override on the command line if needed.
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_TIME ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

MODULE  := github.com/quie446/minisvc
PKG     := ./cmd/minisvc
# Variables live in package main: the linker addresses them as main.* —
# the full importpath form (module/cmd/minisvc.Version) is silently ignored.
LDFLAGS := -s -w \
	-X main.Version=$(VERSION) \
	-X main.Commit=$(COMMIT) \
	-X main.BuildTime=$(BUILD_TIME)

# Picked up by docker compose "build.args" automatically.
export VERSION COMMIT BUILD_TIME

IMAGE        ?= minisvc:$(VERSION)
RELEASE_FILE := deploy/docker-compose.yml
DEV_FILE     := deploy/docker-compose.dev.yml
PORT         ?= 8080

.PHONY: help version test build image up up-dev down smoke deliver logs ps clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

version: ## Print stamped version metadata
	@echo "version=$(VERSION) commit=$(COMMIT) build_time=$(BUILD_TIME)"

test: ## Run unit tests
	go test ./... -race -count=1

build: ## Build local binary with version metadata into bin/
	mkdir -p bin
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/minisvc $(PKG)

image: ## Build the multi-stage release image (binary + migrations + config only)
	docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg COMMIT=$(COMMIT) \
	--build-arg BUILD_TIME=$(BUILD_TIME) \
		-t $(IMAGE) .

up: ## Start the release compose stack (deps + service)
	docker compose -f $(RELEASE_FILE) up -d --build

up-dev: ## Dev posture: local configs/migrations bind-mounted, local data dir
	docker compose -f $(RELEASE_FILE) -f $(DEV_FILE) up -d --build

down: ## Stop and remove the compose stack (named volume is kept)
	docker compose -f $(RELEASE_FILE) -f $(DEV_FILE) down --remove-orphans 2>/dev/null \
		|| docker compose -f $(RELEASE_FILE) down --remove-orphans

smoke: ## Hit health/ready/version/ping; fails non-zero on any problem
	scripts/smoke.sh "$(PORT)" "$(COMMIT)"

deliver: ## Clean-room flow: down -> test -> image -> up -> smoke
	scripts/deliver.sh "$(PORT)"

logs: ## Tail service logs
	docker compose -f $(RELEASE_FILE) logs -f --tail=100

ps: ## Show compose status
	docker compose -f $(RELEASE_FILE) ps

clean: down ## Stop stack and remove local build output/data
	rm -rf bin data
