package config

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Load is a tiny hand-rolled yaml-ish reader (no deps). Keys: env, port, data_dir, migrations_dir, health_path.
type Config struct {
	Env           string
	Port          int
	DataDir       string
	MigrationsDir string
	HealthPath    string
}

func Load(path string) (*Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	cfg := &Config{
		Env:           "dev",
		Port:          8080,
		DataDir:       "./data",
		MigrationsDir: "migrations",
		HealthPath:    "/healthz",
	}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		k := strings.TrimSpace(parts[0])
		v := strings.TrimSpace(parts[1])
		v = strings.Trim(v, `"'`)
		switch k {
		case "env":
			cfg.Env = v
		case "port":
			n, err := strconv.Atoi(v)
			if err != nil {
				return nil, fmt.Errorf("port: %w", err)
			}
			cfg.Port = n
		case "data_dir":
			cfg.DataDir = v
		case "migrations_dir":
			cfg.MigrationsDir = v
		case "health_path":
			cfg.HealthPath = v
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return cfg, nil
}
