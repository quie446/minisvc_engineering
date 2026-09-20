# syntax=docker/dockerfile:1
# Multi-stage build: toolchain + module cache stay in the builder stage only.

FROM golang:1.22-bookworm AS builder

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_TIME=unknown

WORKDIR /src

# Resolve dependencies first for better layer caching.
COPY go.mod ./
COPY go.su[m] ./
RUN go mod download

# Application sources only (see .dockerignore for what is excluded).
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
	-ldflags "-s -w \
	-X main.Version=${VERSION} \
	-X main.Commit=${COMMIT} \
	-X main.BuildTime=${BUILD_TIME}" \
	-o /out/minisvc ./cmd/minisvc

# Minimal runtime: binary + migrations + release config, no source, no module cache.
FROM alpine:3.20 AS runtime

RUN apk add --no-cache wget \
	&& addgroup -S minisvc \
	&& adduser -S -G minisvc -h /var/lib/minisvc minisvc

COPY --from=builder /out/minisvc /usr/local/bin/minisvc
COPY --chown=minisvc:minisvc migrations/ /migrations/
COPY --chown=minisvc:minisvc deploy/app.prod.yaml /etc/minisvc/app.yaml

USER minisvc
WORKDIR /

LABEL org.opencontainers.image.title="minisvc"

EXPOSE 8080

# Same probe compose uses; kept in the image so `docker run` is monitored too.
HEALTHCHECK --interval=5s --timeout=3s --retries=10 --start-period=5s \
	CMD wget -q -O- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/minisvc"]
CMD ["-config", "/etc/minisvc/app.yaml"]
