package store

import (
	"os"
	"path/filepath"
	"testing"
)

func TestApplyMigrations(t *testing.T) {
	tmp := t.TempDir()
	mig := filepath.Join(tmp, "migrations")
	data := filepath.Join(tmp, "data")
	if err := os.MkdirAll(mig, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(mig, "001_init.sql"), []byte("-- init\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := ApplyMigrations(mig, data); err != nil {
		t.Fatal(err)
	}
	if !Ready(data) {
		t.Fatal("expected ready after migrations")
	}
}
