package db

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

	_ "github.com/lib/pq"

	"github.com/pola-collector/internal/models"
)

// DB wraps the sql.DB connection.
type DB struct {
	conn *sql.DB
}

// New opens a Postgres connection and returns a DB handle.
func New(dsn string) (*DB, error) {
	conn, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	conn.SetMaxOpenConns(10)
	conn.SetMaxIdleConns(5)
	conn.SetConnMaxLifetime(5 * time.Minute)

	if err := conn.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return &DB{conn: conn}, nil
}

// Close closes the underlying connection pool.
func (d *DB) Close() error { return d.conn.Close() }

// ─── Schema ──────────────────────────────────────────────────────────────────

// CreateTables creates all required tables if they don't already exist.
// The schema is intentionally verbose so it is self-documenting.
func (d *DB) CreateTables() error {
	ddl := []string{
		// ── Session table ──────────────────────────────────────────────────
		`CREATE TABLE IF NOT EXISTS pcep_sessions (
			id           BIGSERIAL    PRIMARY KEY,
			collected_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			addr         INET         NOT NULL,
			state        TEXT         NOT NULL,
			is_synced    BOOLEAN      NOT NULL,
			caps         TEXT[]       NOT NULL
		)`,

		// Index to quickly fetch the latest snapshot per peer address
		`CREATE INDEX IF NOT EXISTS idx_sessions_addr_collected
			ON pcep_sessions (addr, collected_at DESC)`,

		// ── TED node table ─────────────────────────────────────────────────
		// One row per router per collection cycle.
		`CREATE TABLE IF NOT EXISTS ted_nodes (
			id           BIGSERIAL    PRIMARY KEY,
			collected_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
			router_id    TEXT         NOT NULL,
			hostname     TEXT         NOT NULL,
			asn          INTEGER      NOT NULL,
			isis_area_id TEXT         NOT NULL,
			srgb_begin   INTEGER      NOT NULL,
			srgb_end     INTEGER      NOT NULL
		)`,

		`CREATE INDEX IF NOT EXISTS idx_ted_nodes_router_collected
			ON ted_nodes (router_id, collected_at DESC)`,

		// ── TED link table ─────────────────────────────────────────────────
		// One row per directed link per collection cycle.
		`CREATE TABLE IF NOT EXISTS ted_links (
			id              BIGSERIAL   PRIMARY KEY,
			ted_node_id     BIGINT      NOT NULL REFERENCES ted_nodes(id) ON DELETE CASCADE,
			collected_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			adj_sid         INTEGER     NOT NULL,
			local_ip        INET        NOT NULL,
			remote_ip       INET        NOT NULL,
			remote_node     TEXT        NOT NULL,
			-- flattened metrics (NULL when not advertised)
			metric_igp      INTEGER,
			metric_te       INTEGER,
			metric_delay_us INTEGER     -- microseconds
		)`,

		`CREATE INDEX IF NOT EXISTS idx_ted_links_node
			ON ted_links (ted_node_id)`,

		// ── TED prefix table ───────────────────────────────────────────────
		`CREATE TABLE IF NOT EXISTS ted_prefixes (
			id           BIGSERIAL   PRIMARY KEY,
			ted_node_id  BIGINT      NOT NULL REFERENCES ted_nodes(id) ON DELETE CASCADE,
			collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			prefix       CIDR        NOT NULL,
			sid_index    INTEGER              -- NULL when not a node SID
		)`,

		`CREATE INDEX IF NOT EXISTS idx_ted_prefixes_node
			ON ted_prefixes (ted_node_id)`,
	}

	for _, stmt := range ddl {
		if _, err := d.conn.Exec(stmt); err != nil {
			return fmt.Errorf("DDL failed:\n%s\nerr: %w", stmt, err)
		}
	}
	log.Println("[db] schema verified / created")
	return nil
}

// ─── Session writes ───────────────────────────────────────────────────────────

// InsertSessions bulk-inserts a session snapshot. Each call is one collection
// cycle; the collected_at timestamp ties all rows together.
func (d *DB) InsertSessions(sessions []models.Session) error {
	if len(sessions) == 0 {
		return nil
	}
	now := time.Now().UTC()

	tx, err := d.conn.Begin()
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	stmt, err := tx.Prepare(`
		INSERT INTO pcep_sessions (collected_at, addr, state, is_synced, caps)
		VALUES ($1, $2, $3, $4, $5)
	`)
	if err != nil {
		return fmt.Errorf("prepare session insert: %w", err)
	}
	defer stmt.Close()

	for _, s := range sessions {
		capsArr := "{" + strings.Join(s.Caps, ",") + "}"
		if _, err = stmt.Exec(now, s.Addr, s.State, s.IsSynced, capsArr); err != nil {
			return fmt.Errorf("insert session %s: %w", s.Addr, err)
		}
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit sessions: %w", err)
	}
	log.Printf("[db] inserted %d session rows", len(sessions))
	return nil
}

// ─── TED writes ───────────────────────────────────────────────────────────────

// InsertTEDNodes inserts the full TED snapshot (nodes + links + prefixes)
// in a single transaction.
func (d *DB) InsertTEDNodes(nodes []models.TEDNode) error {
	if len(nodes) == 0 {
		return nil
	}
	now := time.Now().UTC()

	tx, err := d.conn.Begin()
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	nodeStmt, err := tx.Prepare(`
		INSERT INTO ted_nodes (collected_at, router_id, hostname, asn, isis_area_id, srgb_begin, srgb_end)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id
	`)
	if err != nil {
		return fmt.Errorf("prepare node insert: %w", err)
	}
	defer nodeStmt.Close()

	linkStmt, err := tx.Prepare(`
		INSERT INTO ted_links
			(ted_node_id, collected_at, adj_sid, local_ip, remote_ip, remote_node,
			 metric_igp, metric_te, metric_delay_us)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`)
	if err != nil {
		return fmt.Errorf("prepare link insert: %w", err)
	}
	defer linkStmt.Close()

	prefixStmt, err := tx.Prepare(`
		INSERT INTO ted_prefixes (ted_node_id, collected_at, prefix, sid_index)
		VALUES ($1, $2, $3, $4)
	`)
	if err != nil {
		return fmt.Errorf("prepare prefix insert: %w", err)
	}
	defer prefixStmt.Close()

	for _, node := range nodes {
		var nodeID int64
		err = nodeStmt.QueryRow(
			now,
			node.RouterID, node.Hostname, node.ASN,
			node.ISISAreaID, node.SRGBBegin, node.SRGBEnd,
		).Scan(&nodeID)
		if err != nil {
			return fmt.Errorf("insert node %s: %w", node.Hostname, err)
		}

		// ── links
		for _, link := range node.Links {
			igp, te, delay := extractMetrics(link.Metrics)
			_, err = linkStmt.Exec(
				nodeID, now,
				link.AdjSID, link.LocalIP, link.RemoteIP, link.RemoteNode,
				igp, te, delay,
			)
			if err != nil {
				return fmt.Errorf("insert link %s->%s: %w", link.LocalIP, link.RemoteIP, err)
			}
		}

		// ── prefixes
		for _, pfx := range node.Prefixes {
			_, err = prefixStmt.Exec(nodeID, now, pfx.Prefix, pfx.SIDIndex)
			if err != nil {
				return fmt.Errorf("insert prefix %s: %w", pfx.Prefix, err)
			}
		}
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit ted: %w", err)
	}
	log.Printf("[db] inserted TED snapshot: %d nodes", len(nodes))
	return nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func extractMetrics(metrics []models.Metric) (igp, te, delay *int) {
	for _, m := range metrics {
		v := m.Value
		switch m.Type {
		case "METRIC_TYPE_IGP":
			igp = &v
		case "METRIC_TYPE_TE":
			te = &v
		case "METRIC_TYPE_DELAY":
			delay = &v
		}
	}
	return
}
