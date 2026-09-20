VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT    ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_TIME ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS   := -s -w -X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.BuildTime=$(BUILD_TIME)
IMAGE     ?= minisvc:$(VERSION)

export VERSION COMMIT BUILD_TIME

.PHONY: test build image up smoke down release clean

test:
	go test ./...

build:
	mkdir -p bin
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/minisvc ./cmd/minisvc

image:
	docker build \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg COMMIT=$(COMMIT) \
	  --build-arg BUILD_TIME=$(BUILD_TIME) \
	  -t $(IMAGE) .

up: image
	docker compose up -d --wait

smoke:
	EXPECTED_VERSION=$(VERSION) EXPECTED_COMMIT=$(COMMIT) ./scripts/smoke.sh

down:
	docker compose down -v

release: test build image up smoke
	@echo "release OK: $(IMAGE) ($(COMMIT))"

clean: down
	rm -rf bin data
