# syntax=docker/dockerfile:1

# ---- build stage ----
FROM golang:1.22-bookworm AS build
WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_TIME=unknown
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X main.Version=${VERSION} -X main.Commit=${COMMIT} -X main.BuildTime=${BUILD_TIME}" \
      -o /out/minisvc ./cmd/minisvc

# ---- runtime stage: binary + migrations + default config only ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=build /out/minisvc /usr/local/bin/minisvc
COPY migrations/ /migrations/
COPY deploy/app.prod.yaml /config/app.yaml
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/minisvc", "-config", "/config/app.yaml"]
