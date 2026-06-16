package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
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

// ─── Schema check ─────────────────────────────────────────────────────────────

// CreateTables verifies the required platform tables exist.
// The schema is owned externally — we never CREATE or DROP here.
func (d *DB) CreateTables() error {
	required := []string{"network", "node", "link", "prefix", "session"}
	for _, tbl := range required {
		var exists bool
		err := d.conn.QueryRow(`
			SELECT EXISTS (
				SELECT 1 FROM information_schema.tables
				WHERE table_schema = 'public' AND table_name = $1
			)`, tbl).Scan(&exists)
		if err != nil {
			return fmt.Errorf("checking table %q: %w", tbl, err)
		}
		if !exists {
			return fmt.Errorf("required table %q not found — is POSTGRES_DSN pointing at the right database?", tbl)
		}
	}
	log.Println("[db] schema check passed: network, node, link, prefix, session all present")
	return nil
}

// ─── Network ─────────────────────────────────────────────────────────────────

// EnsureNetwork finds or creates the network row for this ASN and returns its id.
// Uses SELECT-then-INSERT to avoid needing a unique constraint on asn.
func (d *DB) EnsureNetwork(nodes []models.TEDNode) (int64, error) {
	if len(nodes) == 0 {
		return 0, fmt.Errorf("cannot ensure network: no TED nodes")
	}
	n := nodes[0]

	// Try to find existing network by ASN
	var id int64
	err := d.conn.QueryRow(
		`SELECT id FROM network WHERE asn = $1 LIMIT 1`, n.ASN,
	).Scan(&id)

	if err == nil {
		// Found — update SRGB in case it changed
		_, err = d.conn.Exec(
			`UPDATE network SET srgb_begin = $1, srgb_end = $2 WHERE id = $3`,
			n.SRGBBegin, n.SRGBEnd, id)
		if err != nil {
			log.Printf("[db] warning: could not update network srgb: %v", err)
		}
		log.Printf("[db] found existing network id=%d  asn=%d", id, n.ASN)
		return id, nil
	}
	if err != sql.ErrNoRows {
		return 0, fmt.Errorf("query network by asn: %w", err)
	}

	// Not found — insert
	err = d.conn.QueryRow(`
		INSERT INTO network
		  (name, asn, srgb_begin, srgb_end, srlb_begin, srlb_end,
		   poll_interval_s, read_only, reopt_mode)
		VALUES ($1, $2, $3, $4, 15000, 15999, $5, false, 'propose')
		RETURNING id`,
		"core-mpls", n.ASN, n.SRGBBegin, n.SRGBEnd, pollIntervalS,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("insert network: %w", err)
	}
	log.Printf("[db] created network id=%d  asn=%d  srgb=%d-%d", id, n.ASN, n.SRGBBegin, n.SRGBEnd)
	return id, nil
}

// pollIntervalS can be overridden from config before EnsureNetwork is called.
var pollIntervalS = 60

// ─── TED upsert ───────────────────────────────────────────────────────────────

// UpsertTED upserts the full TED snapshot into node / link / prefix atomically.
// Upsert strategy (SELECT-then-INSERT/UPDATE) avoids relying on unique
// constraints that may not exist — we key on:
//
//	node   → (network_id, system_id)
//	link   → (network_id, local_ip, remote_ip)
//	prefix → (node_id, prefix)
func (d *DB) UpsertTED(networkID int64, nodes []models.TEDNode) error {
	if len(nodes) == 0 {
		return nil
	}

	tx, err := d.conn.Begin()
	if err != nil {
		return fmt.Errorf("begin TED tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	nodeIDBySystemID, err := upsertNodes(tx, networkID, nodes)
	if err != nil {
		return err
	}
	if err = upsertLinks(tx, networkID, nodes, nodeIDBySystemID); err != nil {
		return err
	}
	if err = upsertPrefixes(tx, nodes, nodeIDBySystemID); err != nil {
		return err
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit TED upsert: %w", err)
	}
	log.Printf("[db] upserted TED: %d nodes for network_id=%d", len(nodes), networkID)
	return nil
}

func upsertNodes(tx *sql.Tx, networkID int64, nodes []models.TEDNode) (map[string]int64, error) {
	result := make(map[string]int64, len(nodes))

	for _, n := range nodes {
		routerIP, sidIndex := extractLoopback(n.Prefixes)
		if routerIP == "" {
			log.Printf("[db] node %s has no loopback prefix — skipping", n.Hostname)
			continue
		}
		// var nodeSID *int
		// if sidIndex != nil {
		// 	v := n.SRGBBegin + *sidIndex
		// 	nodeSID = &v
		// }

		// Check if node already exists
		var id int64
		err := tx.QueryRow(
			`SELECT id FROM node WHERE network_id = $1 AND system_id = $2`,
			networkID, n.RouterID,
		).Scan(&id)

		if err == sql.ErrNoRows {
			// Insert new node
			err = tx.QueryRow(`
				INSERT INTO node
				(network_id, system_id, hostname, router_id,
				srgb_begin, srgb_end, sid_index,
				isis_area, status, sr_algorithms)
				VALUES
				($1, $2, $3, $4::inet,
				$5, $6, $7,
				$8, 'up', '{0}')
				RETURNING id`,
				networkID,
				n.RouterID,
				n.Hostname,
				routerIP,
				n.SRGBBegin,
				n.SRGBEnd,
				sidIndex,
				n.ISISAreaID,
			).Scan(&id)
			if err != nil {
				return nil, fmt.Errorf("insert node %s: %w", n.Hostname, err)
			}
			log.Printf("[db]   node INSERT %-10s  system_id=%s  router_id=%-12s   id=%d",
				n.Hostname, n.RouterID, routerIP, id)
		} else if err != nil {
			return nil, fmt.Errorf("query node %s: %w", n.Hostname, err)
		} else {
			// Update existing node
			_, err = tx.Exec(`
				UPDATE node SET
				hostname     = $1,
				router_id    = $2::inet,
				srgb_begin   = $3,
				srgb_end     = $4,
				sid_index    = $5,
				isis_area    = $6,
				status       = 'up',
				last_seen_at = NOW()
				WHERE id = $7`,
				n.Hostname,
				routerIP,
				n.SRGBBegin,
				n.SRGBEnd,
				sidIndex,
				n.ISISAreaID,
				id,
			)
			if err != nil {
				return nil, fmt.Errorf("update node %s: %w", n.Hostname, err)
			}
			log.Printf("[db]   node UPDATE %-10s  system_id=%s  id=%d", n.Hostname, n.RouterID, id)
		}
		result[n.RouterID] = id
	}
	return result, nil
}

func upsertLinks(tx *sql.Tx, networkID int64, nodes []models.TEDNode, nodeIDBySystemID map[string]int64) error {
	for _, n := range nodes {
		localNodeID, ok := nodeIDBySystemID[n.RouterID]
		if !ok {
			log.Printf("[db] link upsert: no db id for local node %s — skipping its links", n.RouterID)
			continue
		}

		for _, l := range n.Links {
			igp, te, delay := extractMetrics(l.Metrics)

			var remoteNodeID sql.NullInt64
			if rid, ok := nodeIDBySystemID[l.RemoteNode]; ok {
				remoteNodeID = sql.NullInt64{Int64: rid, Valid: true}
			}

			// Check if link already exists
			var id int64
			err := tx.QueryRow(
				`SELECT id FROM link WHERE network_id = $1 AND local_ip = $2::inet AND remote_ip = $3::inet`,
				networkID, l.LocalIP, l.RemoteIP,
			).Scan(&id)

			if err == sql.ErrNoRows {
				_, err = tx.Exec(`
					INSERT INTO link
					  (network_id, local_node_id, remote_node_id,
					   local_ip, remote_ip,
					   igp_metric, te_metric, delay_us,
					   adj_sid, status)
					VALUES
					  ($1, $2, $3,
					   $4::inet, $5::inet,
					   $6, $7, $8,
					   $9, 'up')`,
					networkID, localNodeID, remoteNodeID,
					l.LocalIP, l.RemoteIP,
					igp, te, delay, l.AdjSID,
				)
				if err != nil {
					return fmt.Errorf("insert link %s→%s: %w", l.LocalIP, l.RemoteIP, err)
				}
			} else if err != nil {
				return fmt.Errorf("query link %s→%s: %w", l.LocalIP, l.RemoteIP, err)
			} else {
				_, err = tx.Exec(`
					UPDATE link SET
					  local_node_id  = $1,
					  remote_node_id = $2,
					  igp_metric     = $3,
					  te_metric      = $4,
					  delay_us       = $5,
					  adj_sid        = $6,
					  status         = 'up',
					  last_seen_at   = NOW()
					WHERE id = $7`,
					localNodeID, remoteNodeID,
					igp, te, delay, l.AdjSID, id,
				)
				if err != nil {
					return fmt.Errorf("update link %s→%s: %w", l.LocalIP, l.RemoteIP, err)
				}
			}
		}
	}
	return nil
}

func upsertPrefixes(tx *sql.Tx, nodes []models.TEDNode, nodeIDBySystemID map[string]int64) error {
	for _, n := range nodes {
		nodeID, ok := nodeIDBySystemID[n.RouterID]
		if !ok {
			continue
		}
		for _, p := range n.Prefixes {
			// isLoopback := strings.HasSuffix(p.Prefix, "/32")
			var id int64
			err := tx.QueryRow(
				`SELECT id FROM prefix WHERE node_id = $1 AND prefix = $2::cidr`,
				nodeID, p.Prefix,
			).Scan(&id)

			if err == sql.ErrNoRows {
				_, err = tx.Exec(`
					INSERT INTO prefix (node_id, prefix, sid_index, is_loopback)
					VALUES ($1, $2::cidr, $3)`,
					nodeID, p.Prefix, p.SIDIndex)
				if err != nil {
					return fmt.Errorf("insert prefix %s on %s: %w", p.Prefix, n.Hostname, err)
				}
			} else if err != nil {
				return fmt.Errorf("query prefix %s on %s: %w", p.Prefix, n.Hostname, err)
			} else {
				_, err = tx.Exec(`
					UPDATE prefix SET
					sid_index    = $1,
					last_seen_at = NOW()
					WHERE id = $2`,
					p.SIDIndex,
					id,
				)
				if err != nil {
					return fmt.Errorf("update prefix %s on %s: %w", p.Prefix, n.Hostname, err)
				}
			}
		}
	}
	return nil
}

// ─── Session upsert ───────────────────────────────────────────────────────────

// UpsertSessions upserts PCEP sessions. Keyed on (network_id, pcc_addr).
// node_id is resolved by matching pcc_addr against node.oob_addr.
func (d *DB) UpsertSessions(networkID int64, sessions []models.Session) error {
	if len(sessions) == 0 {
		return nil
	}

	tx, err := d.conn.Begin()
	if err != nil {
		return fmt.Errorf("begin session tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	nodeByOOB, err := fetchNodeByOOB(tx, networkID)
	if err != nil {
		return err
	}

	for _, s := range sessions {
		capsJSON, merr := json.Marshal(s.Caps)
		if merr != nil {
			return fmt.Errorf("marshal caps for %s: %w", s.Addr, merr)
		}

		capSet := toSet(s.Caps)
		stateful := capSet["Stateful"]
		instantiation := capSet["Instantiation"]
		srTE := capSet["SR-TE"]
		srv6TE := capSet["SRv6-TE"]

		var nodeID sql.NullInt64
		if id, ok := nodeByOOB[s.Addr]; ok {
			nodeID = sql.NullInt64{Int64: id, Valid: true}
		}

		// Check if session already exists
		var id int64
		err = tx.QueryRow(
			`SELECT id FROM session WHERE network_id = $1 AND pcc_addr = $2::inet`,
			networkID, s.Addr,
		).Scan(&id)

		if err == sql.ErrNoRows {
			_, err = tx.Exec(`
				INSERT INTO session
				  (network_id, pcc_addr, node_id, state, synced,
				   caps, stateful, instantiation, sr_te, srv6_te)
				VALUES ($1, $2::inet, $3, $4, $5, $6::jsonb, $7, $8, $9, $10)`,
				networkID, s.Addr, nodeID, s.State, s.IsSynced,
				string(capsJSON), stateful, instantiation, srTE, srv6TE,
			)
			if err != nil {
				return fmt.Errorf("insert session %s: %w", s.Addr, err)
			}
			log.Printf("[db]   session INSERT %-16s  state=%s  node_id=%v", s.Addr, s.State, nodeID)
		} else if err != nil {
			return fmt.Errorf("query session %s: %w", s.Addr, err)
		} else {
			_, err = tx.Exec(`
				UPDATE session SET
				  node_id       = $1,
				  synced        = $2,
				  caps          = $3::jsonb,
				  stateful      = $4,
				  instantiation = $5,
				  sr_te         = $6,
				  srv6_te       = $7,
				  last_change_at = CASE WHEN state != $8 THEN NOW() ELSE last_change_at END,
				  state         = $8,
				  last_seen_at  = NOW()
				WHERE id = $9`,
				nodeID, s.IsSynced, string(capsJSON),
				stateful, instantiation, srTE, srv6TE,
				s.State, id,
			)
			if err != nil {
				return fmt.Errorf("update session %s: %w", s.Addr, err)
			}
			log.Printf("[db]   session UPDATE %-16s  state=%s  node_id=%v", s.Addr, s.State, nodeID)
		}
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit sessions: %w", err)
	}
	log.Printf("[db] upserted %d sessions for network_id=%d", len(sessions), networkID)
	return nil
}

// ─── Snapshot ────────────────────────────────────────────────────────────────

// RecordSnapshot writes a point-in-time freeze of the current topology.
func (d *DB) RecordSnapshot(networkID int64) error {
	tx, err := d.conn.Begin()
	if err != nil {
		return fmt.Errorf("begin snapshot tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var snapID int64
	err = tx.QueryRow(`
		INSERT INTO snapshot (network_id, node_count, link_count)
		SELECT $1,
		  (SELECT COUNT(*) FROM node WHERE network_id = $1 AND status = 'up'),
		  (SELECT COUNT(*) FROM link WHERE network_id = $1 AND status = 'up')
		RETURNING id`, networkID).Scan(&snapID)
	if err != nil {
		return fmt.Errorf("insert snapshot: %w", err)
	}

	_, err = tx.Exec(`
		INSERT INTO snapshot_node (snapshot_id, taken_at, system_id, hostname, router_id, status)
		SELECT $1, NOW(), system_id, hostname, router_id, status
		FROM node WHERE network_id = $2`, snapID, networkID)
	if err != nil {
		return fmt.Errorf("insert snapshot_node: %w", err)
	}

	_, err = tx.Exec(`
		INSERT INTO snapshot_link
		  (snapshot_id, taken_at, local_ip, remote_ip,
		   igp_metric, te_metric, delay_us, adj_sid, status)
		SELECT $1, NOW(), local_ip, remote_ip,
		       igp_metric, te_metric, delay_us, adj_sid, status
		FROM link WHERE network_id = $2`, snapID, networkID)
	if err != nil {
		return fmt.Errorf("insert snapshot_link: %w", err)
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit snapshot: %w", err)
	}
	log.Printf("[db] snapshot id=%d recorded for network_id=%d", snapID, networkID)
	return nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func fetchNodeByOOB(tx *sql.Tx, networkID int64) (map[string]int64, error) {
	rows, err := tx.Query(
		`SELECT oob_addr::text, id FROM node WHERE network_id = $1 AND oob_addr IS NOT NULL`,
		networkID)
	if err != nil {
		return nil, fmt.Errorf("fetch oob_addr map: %w", err)
	}
	defer rows.Close()
	m := make(map[string]int64)
	for rows.Next() {
		var addr string
		var id int64
		if err := rows.Scan(&addr, &id); err != nil {
			return nil, err
		}
		m[addr] = id
	}
	return m, rows.Err()
}

func extractLoopback(prefixes []models.Prefix) (ip string, sidIndex *int) {
	for _, p := range prefixes {
		if p.SIDIndex != nil {
			return stripMask(p.Prefix), p.SIDIndex
		}
	}
	return "", nil
}

func stripMask(cidr string) string {
	for i, c := range cidr {
		if c == '/' {
			return cidr[:i]
		}
	}
	return cidr
}

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

func toSet(ss []string) map[string]bool {
	m := make(map[string]bool, len(ss))
	for _, s := range ss {
		m[s] = true
	}
	return m
}

// Ensure the import of "time" is used (it's used by SetConnMaxLifetime).
var _ = time.Minute
