# pola-collector

A Go daemon that polls the `pola` PCE CLI on a configurable interval and
persists session and TED snapshots to PostgreSQL.

---

## Schema

```
pcep_sessions
├── id           BIGSERIAL PK
├── collected_at TIMESTAMPTZ
├── addr         INET
├── state        TEXT
├── is_synced    BOOLEAN
└── caps         TEXT[]

ted_nodes
├── id           BIGSERIAL PK
├── collected_at TIMESTAMPTZ
├── router_id    TEXT          ← ISIS sys-id, e.g. 0000.0000.0001
├── hostname     TEXT
├── asn          INTEGER
├── isis_area_id TEXT
├── srgb_begin   INTEGER
└── srgb_end     INTEGER

ted_links  (FK → ted_nodes.id)
├── id              BIGSERIAL PK
├── ted_node_id     BIGINT FK
├── collected_at    TIMESTAMPTZ
├── adj_sid         INTEGER
├── local_ip        INET
├── remote_ip       INET
├── remote_node     TEXT
├── metric_igp      INTEGER   (NULL if not advertised)
├── metric_te       INTEGER   (NULL if not advertised)
└── metric_delay_us INTEGER   (NULL if not advertised, in microseconds)

ted_prefixes  (FK → ted_nodes.id)
├── id           BIGSERIAL PK
├── ted_node_id  BIGINT FK
├── collected_at TIMESTAMPTZ
├── prefix       CIDR
└── sid_index    INTEGER    (NULL for non-node SIDs)
```

---

## Environment variables

| Variable           | Default                                                                  | Description                                      |
|--------------------|--------------------------------------------------------------------------|--------------------------------------------------|
| `POLA_BINARY`      | `./pola`                                                                 | Path to the pola CLI binary                      |
| `POLA_PORT`        | `50052`                                                                  | gRPC port                                        |
| `POLA_HOST`        | _(empty)_                                                                | gRPC host (empty = pola's default)               |
| `POSTGRES_DSN`     | `host=localhost port=5432 user=pola password=pola dbname=pola sslmode=disable` | libpq DSN                               |
| `COLLECT_INTERVAL` | `1m`                                                                     | Poll interval (Go duration: `30s`, `5m`, `1h` …) |
| `DB_CONN_RETRIES`  | `5`                                                                      | Initial DB connection retry count                |
| `DB_CONN_DELAY`    | `3s`                                                                     | Delay between DB connection retries              |

---

## Quick start

### Local (binary)

```bash
cp .env.example .env
# edit .env to point at your pola binary and postgres

export $(grep -v '^#' .env | xargs)
go run ./cmd
```

### Docker Compose

```bash
docker-compose up --build
```

---

## Useful queries

### Latest session state per peer
```sql
SELECT DISTINCT ON (addr)
    addr, state, is_synced, caps, collected_at
FROM pcep_sessions
ORDER BY addr, collected_at DESC;
```

### Current TED topology (nodes + link count)
```sql
SELECT
    n.hostname,
    n.router_id,
    n.asn,
    COUNT(l.id) AS link_count,
    n.collected_at
FROM ted_nodes n
JOIN ted_links l ON l.ted_node_id = n.id
WHERE n.collected_at = (SELECT MAX(collected_at) FROM ted_nodes)
GROUP BY n.id
ORDER BY n.hostname;
```

### Links with lowest delay from a specific node
```sql
SELECT
    n.hostname       AS src,
    l.local_ip,
    l.remote_ip,
    l.remote_node,
    l.metric_delay_us,
    l.metric_igp
FROM ted_nodes n
JOIN ted_links l ON l.ted_node_id = n.id
WHERE n.hostname = 'R1-PE'
  AND n.collected_at = (SELECT MAX(collected_at) FROM ted_nodes)
ORDER BY l.metric_delay_us ASC NULLS LAST;
```

### Node SIDs (prefix SIDs) in current snapshot
```sql
SELECT
    n.hostname,
    p.prefix,
    n.srgb_begin + p.sid_index AS absolute_label
FROM ted_nodes n
JOIN ted_prefixes p ON p.ted_node_id = n.id
WHERE p.sid_index IS NOT NULL
  AND n.collected_at = (SELECT MAX(collected_at) FROM ted_nodes)
ORDER BY p.sid_index;
```

### Delay trend for a specific link over time
```sql
SELECT
    l.collected_at,
    l.metric_delay_us
FROM ted_links l
JOIN ted_nodes n ON n.id = l.ted_node_id
WHERE n.hostname  = 'R1-PE'
  AND l.remote_node = '0000.0000.0002'
ORDER BY l.collected_at;
```

---

## Why not Neo4j?

| Concern                        | PostgreSQL                          | Neo4j                                  |
|--------------------------------|-------------------------------------|----------------------------------------|
| Graph traversal (shortest path)| Recursive CTEs, painful             | Native Cypher, excellent               |
| Time-series snapshots          | Excellent (TIMESTAMPTZ + indices)   | Requires extra modelling               |
| Ops complexity                 | Simple                              | Higher                                 |
| SQL tooling / Grafana          | First-class                         | Plugin needed                          |

**Recommendation:** Start with Postgres. If you find yourself writing many
recursive CTEs for path computation against the TED, add Neo4j (or pgRouting)
alongside. Session data stays in Postgres forever.
