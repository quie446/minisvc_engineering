# WIP image — CI and laptop disagree on what gets shipped
FROM golang:1.22-bookworm
WORKDIR /src
COPY go.mod ./
COPY . .
RUN go build -o /minisvc ./cmd/minisvc
# NOTE: migrations/ not copied into a slim runtime layer; whole /src stays
EXPOSE 8080
# wrong default config path relative to how compose mounts things
CMD ["/minisvc", "-config", "/config/app.yaml"]
