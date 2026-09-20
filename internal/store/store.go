package store

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func ApplyMigrations(migDir, dataDir string) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return err
	}
	entries, err := os.ReadDir(migDir)
	if err != nil {
		return fmt.Errorf("read migrations %s: %w", migDir, err)
	}
	var names []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if strings.HasSuffix(e.Name(), ".sql") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	appliedPath := filepath.Join(dataDir, "applied.txt")
	var applied []byte
	if b, err := os.ReadFile(appliedPath); err == nil {
		applied = b
	}
	for _, name := range names {
		if strings.Contains(string(applied), name) {
			continue
		}
		body, err := os.ReadFile(filepath.Join(migDir, name))
		if err != nil {
			return err
		}
		// pretend apply: write a marker file with migration body length
		marker := filepath.Join(dataDir, strings.TrimSuffix(name, ".sql")+".applied")
		if err := os.WriteFile(marker, []byte(fmt.Sprintf("bytes=%d\n", len(body))), 0o644); err != nil {
			return err
		}
		applied = append(applied, []byte(name+"\n")...)
	}
	return os.WriteFile(appliedPath, applied, 0o644)
}

func Ready(dataDir string) bool {
	_, err := os.Stat(filepath.Join(dataDir, "applied.txt"))
	return err == nil
}
