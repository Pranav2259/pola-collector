package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/pola-collector/internal/collector"
	"github.com/pola-collector/internal/db"
)

// ─── Config ──────────────────────────────────────────────────────────────────

type config struct {
	// pola binary
	PolaBinary string
	PolaPort   string
	PolaHost   string

	// postgres
	PostgresDSN string

	// timing
	CollectInterval time.Duration
	DBConnRetries   int
	DBConnDelay     time.Duration
}

func loadConfig() config {
	return config{
		PolaBinary:      getEnv("POLA_BINARY", "./pola"),
		PolaPort:        getEnv("POLA_PORT", "50052"),
		PolaHost:        getEnv("POLA_HOST", ""),
		PostgresDSN:     getEnv("POSTGRES_DSN", "host=localhost port=5432 user=pola password=pola dbname=pola sslmode=disable"),
		CollectInterval: getDurationEnv("COLLECT_INTERVAL", 60*time.Second),
		DBConnRetries:   getIntEnv("DB_CONN_RETRIES", 5),
		DBConnDelay:     getDurationEnv("DB_CONN_DELAY", 3*time.Second),
	}
}

// ─── Main ────────────────────────────────────────────────────────────────────

func main() {
	cfg := loadConfig()

	log.Printf("[main] starting pola-collector")
	log.Printf("[main] pola binary  : %s", cfg.PolaBinary)
	log.Printf("[main] pola endpoint: %s:%s", cfg.PolaHost, cfg.PolaPort)
	log.Printf("[main] collect every: %s", cfg.CollectInterval)

	// ── connect to postgres (with retries) ───────────────────────────────
	database, err := connectWithRetry(cfg)
	if err != nil {
		log.Fatalf("[main] could not connect to postgres: %v", err)
	}
	defer database.Close()

	// ── ensure schema exists ─────────────────────────────────────────────
	if err := database.CreateTables(); err != nil {
		log.Fatalf("[main] schema creation failed: %v", err)
	}

	// ── start collection loop ─────────────────────────────────────────────
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go collectionLoop(ctx, cfg, database)

	// ── wait for signal ───────────────────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	log.Printf("[main] received %s, shutting down", sig)
}

// ─── Collection loop ─────────────────────────────────────────────────────────

func collectionLoop(ctx context.Context, cfg config, database *db.DB) {
	colCfg := collector.Config{
		Binary: cfg.PolaBinary,
		Port:   cfg.PolaPort,
		Host:   cfg.PolaHost,
	}

	// Run immediately on start, then on every tick.
	collect(colCfg, database)

	ticker := time.NewTicker(cfg.CollectInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("[loop] context cancelled, stopping")
			return
		case t := <-ticker.C:
			log.Printf("[loop] tick at %s", t.Format(time.RFC3339))
			collect(colCfg, database)
		}
	}
}

func collect(cfg collector.Config, database *db.DB) {
	// ── sessions ─────────────────────────────────────────────────────────
	sessions, cmd, err := collector.CollectSessions(cfg)
	if err != nil {
		log.Printf("[collect] session command %q failed: %v", cmd, err)
	} else {
		log.Printf("[collect] got %d sessions from: %s", len(sessions), cmd)
		if err := database.InsertSessions(sessions); err != nil {
			log.Printf("[collect] insert sessions failed: %v", err)
		}
	}

	// ── TED ──────────────────────────────────────────────────────────────
	nodes, cmd, err := collector.CollectTED(cfg)
	if err != nil {
		log.Printf("[collect] TED command %q failed: %v", cmd, err)
	} else {
		log.Printf("[collect] got %d TED nodes from: %s", len(nodes), cmd)
		if err := database.InsertTEDNodes(nodes); err != nil {
			log.Printf("[collect] insert TED failed: %v", err)
		}
	}
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func connectWithRetry(cfg config) (*db.DB, error) {
	var (
		database *db.DB
		err      error
	)
	for i := 1; i <= cfg.DBConnRetries; i++ {
		database, err = db.New(cfg.PostgresDSN)
		if err == nil {
			log.Printf("[db] connected on attempt %d", i)
			return database, nil
		}
		log.Printf("[db] attempt %d/%d failed: %v", i, cfg.DBConnRetries, err)
		time.Sleep(cfg.DBConnDelay)
	}
	return nil, err
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getIntEnv(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}

func getDurationEnv(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
		log.Printf("[config] invalid duration for %s=%q, using default %s", key, v, fallback)
	}
	return fallback
}
