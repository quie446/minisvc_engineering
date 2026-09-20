package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/quie446/minisvc/internal/config"
	"github.com/quie446/minisvc/internal/store"
)

// filled by ldflags in a proper release build — currently empty in local scripts
var (
	Version   = "dev"
	Commit    = "unknown"
	BuildTime = "unknown"
)

func main() {
	cfgPath := flag.String("config", "configs/app.yaml", "path to yaml config")
	flag.Parse()

	cfg, err := config.Load(*cfgPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	migDir := cfg.MigrationsDir
	if migDir == "" {
		migDir = "migrations"
	}
	if err := store.ApplyMigrations(migDir, cfg.DataDir); err != nil {
		log.Fatalf("migrations: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if !store.Ready(cfg.DataDir) {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready\n"))
	})
	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]string{
			"version":    Version,
			"commit":     Commit,
			"build_time": BuildTime,
		})
	})
	mux.HandleFunc("/v1/ping", func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"pong": true,
			"ts":   time.Now().UTC().Format(time.RFC3339),
			"env":  cfg.Env,
		})
	})

	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Printf("minisvc listening on %s (config=%s data=%s)", addr, *cfgPath, filepath.Clean(cfg.DataDir))
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

// silence unused on older go toolchains if build tags change
var _ = os.Getenv
