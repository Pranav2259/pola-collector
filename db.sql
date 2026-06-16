--
-- PostgreSQL database dump
--

\restrict PzjpspHDhwsXBk30UOHupjhKcuZ2wVT8TxJFP0hiNXdqpFFeUGLUhhM3iKuuikm

-- Dumped from database version 17.9 (Ubuntu 17.9-1.pgdg22.04+1)
-- Dumped by pg_dump version 17.10 (Ubuntu 17.10-1.pgdg24.04+1)

-- Started on 2026-06-16 12:50:58 IST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 926 (class 1247 OID 58370)
-- Name: audit_result; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.audit_result AS ENUM (
    'ok',
    'error'
);


ALTER TYPE public.audit_result OWNER TO root;

--
-- TOC entry 893 (class 1247 OID 58266)
-- Name: discovery_status; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.discovery_status AS ENUM (
    'up',
    'down',
    'stale'
);


ALTER TYPE public.discovery_status OWNER TO root;

--
-- TOC entry 923 (class 1247 OID 58362)
-- Name: event_severity; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.event_severity AS ENUM (
    'info',
    'warning',
    'critical'
);


ALTER TYPE public.event_severity OWNER TO root;

--
-- TOC entry 920 (class 1247 OID 58344)
-- Name: event_type; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.event_type AS ENUM (
    'LINK_DOWN',
    'LINK_UP',
    'METRIC_CHANGE',
    'NODE_DOWN',
    'REOPTIMIZE',
    'ADMISSION',
    'PCEP',
    'CONGESTION'
);


ALTER TYPE public.event_type OWNER TO root;

--
-- TOC entry 905 (class 1247 OID 58294)
-- Name: policy_metric; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.policy_metric AS ENUM (
    'igp',
    'te',
    'delay'
);


ALTER TYPE public.policy_metric OWNER TO root;

--
-- TOC entry 911 (class 1247 OID 58316)
-- Name: policy_source; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.policy_source AS ENUM (
    'console',
    'pola',
    'reoptimizer'
);


ALTER TYPE public.policy_source OWNER TO root;

--
-- TOC entry 908 (class 1247 OID 58302)
-- Name: policy_status; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.policy_status AS ENUM (
    'up',
    'down',
    'provisioning',
    'failed',
    'proposed',
    'stale'
);


ALTER TYPE public.policy_status OWNER TO root;

--
-- TOC entry 902 (class 1247 OID 58288)
-- Name: policy_type; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.policy_type AS ENUM (
    'explicit',
    'dynamic'
);


ALTER TYPE public.policy_type OWNER TO root;

--
-- TOC entry 890 (class 1247 OID 58260)
-- Name: reopt_mode; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.reopt_mode AS ENUM (
    'auto',
    'propose'
);


ALTER TYPE public.reopt_mode OWNER TO root;

--
-- TOC entry 914 (class 1247 OID 58324)
-- Name: service_sla; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.service_sla AS ENUM (
    'delay',
    'igp',
    'te',
    'bw'
);


ALTER TYPE public.service_sla OWNER TO root;

--
-- TOC entry 917 (class 1247 OID 58334)
-- Name: service_status; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.service_status AS ENUM (
    'bound',
    'pending',
    'verify_failed',
    'unbound'
);


ALTER TYPE public.service_status OWNER TO root;

--
-- TOC entry 899 (class 1247 OID 58280)
-- Name: session_state; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.session_state AS ENUM (
    'up',
    'down',
    'init'
);


ALTER TYPE public.session_state OWNER TO root;

--
-- TOC entry 896 (class 1247 OID 58274)
-- Name: srlg_source; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.srlg_source AS ENUM (
    'admin_group',
    'operator'
);


ALTER TYPE public.srlg_source OWNER TO root;

--
-- TOC entry 929 (class 1247 OID 58376)
-- Name: user_role; Type: TYPE; Schema: public; Owner: root
--

CREATE TYPE public.user_role AS ENUM (
    'viewer',
    'operator',
    'admin'
);


ALTER TYPE public.user_role OWNER TO root;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 232 (class 1259 OID 58526)
-- Name: api_token; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.api_token (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash text NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.api_token OWNER TO root;

--
-- TOC entry 3732 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE api_token; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.api_token IS 'Bearer tokens for write APIs; token_hash stored (never plaintext). scopes[] gate endpoints.';


--
-- TOC entry 231 (class 1259 OID 58525)
-- Name: api_token_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.api_token ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.api_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 254 (class 1259 OID 58798)
-- Name: audit_log; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now() NOT NULL,
    user_id bigint,
    action text NOT NULL,
    endpoint text,
    target_type text,
    target_id bigint,
    dry_run boolean DEFAULT false NOT NULL,
    read_only_blocked boolean DEFAULT false NOT NULL,
    request jsonb,
    result public.audit_result DEFAULT 'ok'::public.audit_result NOT NULL,
    error_detail text,
    rendered_artifact text
);


ALTER TABLE public.audit_log OWNER TO root;

--
-- TOC entry 3733 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE audit_log; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.audit_log IS 'Audit of every device write (who/what/when/dryRun/result). Retained >= 1 year for compliance.';


--
-- TOC entry 3734 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN audit_log.dry_run; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.audit_log.dry_run IS 'True when the request rendered an artifact but did not push to the device.';


--
-- TOC entry 253 (class 1259 OID 58797)
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 251 (class 1259 OID 58746)
-- Name: event; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.event (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now() NOT NULL,
    type public.event_type NOT NULL,
    severity public.event_severity DEFAULT 'info'::public.event_severity NOT NULL,
    detail jsonb DEFAULT '{}'::jsonb NOT NULL,
    link_id bigint,
    node_id bigint,
    policy_id bigint,
    acknowledged_by bigint
);


ALTER TABLE public.event OWNER TO root;

--
-- TOC entry 3735 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE event; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.event IS 'Diff/event stream (the WS feed). TimescaleDB hypertable on ts.';


--
-- TOC entry 3736 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN event.detail; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.event.detail IS 'Structured payload: old/new metric, affected policies, admission reason, etc.';


--
-- TOC entry 250 (class 1259 OID 58745)
-- Name: event_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.event ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 255 (class 1259 OID 58816)
-- Name: health_metric; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.health_metric (
    ts timestamp with time zone DEFAULT now() NOT NULL,
    network_id bigint,
    poll_latency_ms integer,
    parse_errors integer,
    events_per_min integer,
    feed_staleness_s integer
);


ALTER TABLE public.health_metric OWNER TO root;

--
-- TOC entry 3737 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE health_metric; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.health_metric IS 'Ops observability time-series: poll latency, parse errors, events/min, feed staleness.';


--
-- TOC entry 224 (class 1259 OID 58442)
-- Name: link; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.link (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    local_node_id bigint NOT NULL,
    remote_node_id bigint NOT NULL,
    local_ip inet NOT NULL,
    remote_ip inet NOT NULL,
    igp_metric integer,
    te_metric integer,
    delay_us integer,
    max_bw_bps bigint,
    admin_group integer,
    adj_sid integer,
    status public.discovery_status DEFAULT 'up'::public.discovery_status NOT NULL,
    sim_failed boolean DEFAULT false NOT NULL,
    data_quality text[] DEFAULT '{}'::text[] NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    withdrawn_at timestamp with time zone,
    CONSTRAINT link_bw_positive CHECK (((max_bw_bps IS NULL) OR (max_bw_bps > 0))),
    CONSTRAINT link_delay_not_zero CHECK (((delay_us IS NULL) OR (delay_us <> 0))),
    CONSTRAINT link_no_self_loop CHECK ((local_node_id <> remote_node_id)),
    CONSTRAINT link_te_not_zero CHECK (((te_metric IS NULL) OR (te_metric <> 0)))
);


ALTER TABLE public.link OWNER TO root;

--
-- TOC entry 3738 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE link; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.link IS 'Current DIRECTED link state (LINK NLRI / TED). 14 directed rows = 7 bidirectional edges. Paired by v_link_pair.';


--
-- TOC entry 3739 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.local_ip; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.local_ip IS 'Local interface IP — join key for telemetry_sample.';


--
-- TOC entry 3740 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.te_metric; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.te_metric IS 'TE metric. NULL when not advertised (R3->R2, R3->R4). NEVER defaulted to 0.';


--
-- TOC entry 3741 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.delay_us; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.delay_us IS 'Unidirectional delay (microseconds). NULL when absent. NEVER defaulted to 0; delay-CSPF skips NULL links.';


--
-- TOC entry 3742 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.max_bw_bps; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.max_bw_bps IS 'Max Link BW in bytes/s (125000000 = 1 Gbps). Reservable BW is NOT here — see reservation ledger.';


--
-- TOC entry 3743 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.admin_group; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.admin_group IS 'Admin-group bitmap (hex->int) as SRLG/affinity proxy (UC-07). NULL when absent.';


--
-- TOC entry 3744 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.sim_failed; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.sim_failed IS 'UC-06 lab fail-link toggle (simulated outage).';


--
-- TOC entry 3745 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN link.data_quality; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.link.data_quality IS 'Data-quality flags surfaced in UI, e.g. {missing_te,missing_delay} for R3->R2 / R3->R4 (UC-01).';


--
-- TOC entry 223 (class 1259 OID 58441)
-- Name: link_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.link ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 58480)
-- Name: link_metric_history; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.link_metric_history (
    id bigint NOT NULL,
    link_id bigint NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    igp_metric integer,
    te_metric integer,
    delay_us integer,
    admin_group integer
);


ALTER TABLE public.link_metric_history OWNER TO root;

--
-- TOC entry 3746 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE link_metric_history; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.link_metric_history IS 'Discrete metric-change deltas per link (METRIC_CHANGE history); nullable metrics preserved (never 0).';


--
-- TOC entry 225 (class 1259 OID 58479)
-- Name: link_metric_history_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.link_metric_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.link_metric_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 218 (class 1259 OID 58384)
-- Name: network; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.network (
    id bigint NOT NULL,
    name text NOT NULL,
    asn integer NOT NULL,
    srgb_begin integer NOT NULL,
    srgb_end integer NOT NULL,
    srlb_begin integer NOT NULL,
    srlb_end integer NOT NULL,
    collector_host inet,
    poll_interval_s integer DEFAULT 5 NOT NULL,
    read_only boolean DEFAULT false NOT NULL,
    reopt_mode public.reopt_mode DEFAULT 'propose'::public.reopt_mode NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT network_poll_pos CHECK ((poll_interval_s > 0)),
    CONSTRAINT network_srgb_order CHECK ((srgb_begin < srgb_end)),
    CONSTRAINT network_srlb_order CHECK ((srlb_begin < srlb_end))
);


ALTER TABLE public.network OWNER TO root;

--
-- TOC entry 3747 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE network; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.network IS 'Multi-network / lab container (future multi-tenant). One row per managed network.';


--
-- TOC entry 3748 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.asn; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.asn IS 'BGP ASN of the lab, e.g. 65001.';


--
-- TOC entry 3749 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.srgb_begin; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.srgb_begin IS 'SRGB lower bound (16000).';


--
-- TOC entry 3750 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.srgb_end; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.srgb_end IS 'SRGB upper bound (24000).';


--
-- TOC entry 3751 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.srlb_begin; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.srlb_begin IS 'SR Local Block lower bound (15000).';


--
-- TOC entry 3752 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.srlb_end; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.srlb_end IS 'SR Local Block upper bound (16000).';


--
-- TOC entry 3753 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.read_only; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.read_only IS 'Global READ_ONLY mode flag — blocks all device writes when true.';


--
-- TOC entry 3754 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN network.reopt_mode; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.network.reopt_mode IS 'UC-06 closed-loop behavior: auto (apply reroute) or propose (require approval).';


--
-- TOC entry 217 (class 1259 OID 58383)
-- Name: network_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.network ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.network_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 58401)
-- Name: node; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.node (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    system_id text NOT NULL,
    hostname text NOT NULL,
    router_id inet NOT NULL,
    oob_addr inet,
    srgb_begin integer NOT NULL,
    srgb_end integer NOT NULL,
    node_sid integer GENERATED ALWAYS AS ((srgb_begin + (split_part(host(router_id), '.'::text, 4))::integer)) STORED,
    sid_index integer,
    isis_area text NOT NULL,
    vendor text,
    sr_algorithms integer[] DEFAULT '{}'::integer[] NOT NULL,
    status public.discovery_status DEFAULT 'up'::public.discovery_status NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT node_srgb_order CHECK ((srgb_begin < srgb_end))
);


ALTER TABLE public.node OWNER TO root;

--
-- TOC entry 3755 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE node; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.node IS 'Current state of each router (NODE NLRI / TED node). Reconciled each poll.';


--
-- TOC entry 3756 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN node.system_id; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node.system_id IS 'ISIS system-id, the multi-OEM-neutral key, e.g. 0000.0000.0001.';


--
-- TOC entry 3757 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN node.node_sid; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node.node_sid IS 'GENERATED: srgb_begin + last octet of router_id (R1=16001 ... R5=16005). TED index confirms.';


--
-- TOC entry 3758 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN node.sid_index; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node.sid_index IS 'Prefix-SID index from TED (loopback only); NULL otherwise.';


--
-- TOC entry 3759 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN node.vendor; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node.vendor IS 'Descriptive attribute only (e.g. Cisco IOS-XR). NEVER a key (multi-OEM neutral).';


--
-- TOC entry 3760 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN node.status; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node.status IS 'Reconciliation state: up / stale (missed N polls) / down (withdrawn).';


--
-- TOC entry 219 (class 1259 OID 58400)
-- Name: node_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.node ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.node_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 58493)
-- Name: node_srlg; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.node_srlg (
    id bigint NOT NULL,
    node_id bigint,
    link_id bigint,
    srlg_id integer NOT NULL,
    source public.srlg_source DEFAULT 'operator'::public.srlg_source NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT node_srlg_target_chk CHECK (((node_id IS NOT NULL) <> (link_id IS NOT NULL)))
);


ALTER TABLE public.node_srlg OWNER TO root;

--
-- TOC entry 3761 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE node_srlg; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.node_srlg IS 'Operator-supplied SRLG map / override (UC-07). TED has no SRLG; admin_group is the default proxy.';


--
-- TOC entry 3762 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN node_srlg.source; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.node_srlg.source IS 'admin_group (derived) or operator (manual override).';


--
-- TOC entry 227 (class 1259 OID 58492)
-- Name: node_srlg_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.node_srlg ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.node_srlg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 58573)
-- Name: policy; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.policy (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    name text NOT NULL,
    color integer NOT NULL,
    type public.policy_type NOT NULL,
    metric public.policy_metric,
    src_node_id bigint,
    dst_node_id bigint,
    src_addr inet,
    dst_addr inet,
    pcep_session_addr inet,
    preference integer DEFAULT 100 NOT NULL,
    segment_list integer[] DEFAULT '{}'::integer[] NOT NULL,
    computed_cost integer,
    status public.policy_status DEFAULT 'provisioning'::public.policy_status NOT NULL,
    headend_up boolean DEFAULT false NOT NULL,
    source public.policy_source DEFAULT 'console'::public.policy_source NOT NULL,
    rendered_yaml jsonb,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT policy_metric_chk CHECK ((((type = 'dynamic'::public.policy_type) AND (metric IS NOT NULL)) OR ((type = 'explicit'::public.policy_type) AND (metric IS NULL))))
);


ALTER TABLE public.policy OWNER TO root;

--
-- TOC entry 3763 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE policy; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.policy IS 'SR-TE policy / LSP. sr-policy list is empty in real data; console-created only. UC-02/03/04.';


--
-- TOC entry 3764 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN policy.metric; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.policy.metric IS 'Optimization metric for dynamic policies (igp/te/delay); NULL for explicit.';


--
-- TOC entry 3765 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN policy.segment_list; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.policy.segment_list IS 'Ordered node-SID segment list, e.g. {16005,16004}.';


--
-- TOC entry 3766 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN policy.computed_cost; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.policy.computed_cost IS 'Computed path cost in metric units (e.g. delay us). Oracle: via-R5 delay = 6700.';


--
-- TOC entry 3767 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN policy.headend_up; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.policy.headend_up IS 'Cross-check vs PCEP session; false => orphan LSP (v_orphan_lsp, UC-02).';


--
-- TOC entry 3768 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN policy.source; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.policy.source IS 'Provenance: console / pola (discovered) / reoptimizer.';


--
-- TOC entry 235 (class 1259 OID 58572)
-- Name: policy_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.policy ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.policy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 58635)
-- Name: policy_link; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.policy_link (
    policy_id bigint NOT NULL,
    link_id bigint NOT NULL
);


ALTER TABLE public.policy_link OWNER TO root;

--
-- TOC entry 3769 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE policy_link; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.policy_link IS 'N:M policy<->link traversal map. UC-06 affected_policies(failed_link) lookup.';


--
-- TOC entry 238 (class 1259 OID 58612)
-- Name: policy_path_hop; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.policy_path_hop (
    id bigint NOT NULL,
    policy_id bigint NOT NULL,
    seq integer NOT NULL,
    node_id bigint,
    sid integer,
    link_id bigint
);


ALTER TABLE public.policy_path_hop OWNER TO root;

--
-- TOC entry 3770 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE policy_path_hop; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.policy_path_hop IS 'Ordered, resolved hop list backing the canvas route render + segment-list audit.';


--
-- TOC entry 237 (class 1259 OID 58611)
-- Name: policy_path_hop_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.policy_path_hop ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.policy_path_hop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 222 (class 1259 OID 58424)
-- Name: prefix; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.prefix (
    id bigint NOT NULL,
    node_id bigint NOT NULL,
    prefix cidr NOT NULL,
    sid_index integer,
    is_loopback boolean GENERATED ALWAYS AS ((masklen((prefix)::inet) = 32)) STORED,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.prefix OWNER TO root;

--
-- TOC entry 3771 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE prefix; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.prefix IS 'Advertised prefixes (PREFIXv4 NLRI / TED). Loopback /32 carries sid_index; /30 link nets do not.';


--
-- TOC entry 3772 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN prefix.sid_index; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.prefix.sid_index IS 'Prefix-SID index; present only on loopbacks.';


--
-- TOC entry 3773 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN prefix.is_loopback; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.prefix.is_loopback IS 'GENERATED: true when prefix is a /32.';


--
-- TOC entry 221 (class 1259 OID 58423)
-- Name: prefix_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.prefix ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.prefix_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 243 (class 1259 OID 58689)
-- Name: reservation; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.reservation (
    id bigint NOT NULL,
    link_id bigint NOT NULL,
    reserved_bps bigint NOT NULL,
    policy_id bigint,
    demand_label text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reservation_bps_positive CHECK ((reserved_bps > 0))
);


ALTER TABLE public.reservation OWNER TO root;

--
-- TOC entry 3774 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE reservation; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.reservation IS 'BWoD reservation ledger (UC-08). Backend-owned; authoritative source of reservable bandwidth.';


--
-- TOC entry 3775 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN reservation.reserved_bps; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.reservation.reserved_bps IS 'Admitted demand in bytes/s. available = link.max_bw_bps - SUM(reserved_bps) (see v_link_capacity).';


--
-- TOC entry 242 (class 1259 OID 58688)
-- Name: reservation_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.reservation ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.reservation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 241 (class 1259 OID 58652)
-- Name: service; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.service (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    name text NOT NULL,
    vrf text NOT NULL,
    color integer NOT NULL,
    ingress_node_id bigint,
    egress_node_id bigint,
    sla public.service_sla NOT NULL,
    policy_id bigint,
    rendered_config jsonb,
    status public.service_status DEFAULT 'pending'::public.service_status NOT NULL,
    verified_at timestamp with time zone,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.service OWNER TO root;

--
-- TOC entry 3776 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE service; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.service IS 'L3VPN service intent (UC-05 color steering / UC-11 service intent). Operator intent; never auto-reconciled.';


--
-- TOC entry 3777 (class 0 OID 0)
-- Dependencies: 241
-- Name: COLUMN service.policy_id; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.service.policy_id IS 'Bound SR policy; binding succeeds only when a matching (color,dst) policy exists.';


--
-- TOC entry 3778 (class 0 OID 0)
-- Dependencies: 241
-- Name: COLUMN service.status; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.service.status IS 'bound / pending / verify_failed / unbound (provision-then-verify loop).';


--
-- TOC entry 240 (class 1259 OID 58651)
-- Name: service_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.service ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.service_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 234 (class 1259 OID 58544)
-- Name: session; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.session (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    pcc_addr inet NOT NULL,
    node_id bigint,
    state public.session_state NOT NULL,
    synced boolean DEFAULT false NOT NULL,
    caps jsonb DEFAULT '[]'::jsonb NOT NULL,
    stateful boolean GENERATED ALWAYS AS ((caps @> '["Stateful"]'::jsonb)) STORED,
    instantiation boolean GENERATED ALWAYS AS ((caps @> '["Instantiation"]'::jsonb)) STORED,
    sr_te boolean GENERATED ALWAYS AS ((caps @> '["SR-TE"]'::jsonb)) STORED,
    srv6_te boolean GENERATED ALWAYS AS ((caps @> '["SRv6-TE"]'::jsonb)) STORED,
    last_change_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.session OWNER TO root;

--
-- TOC entry 3779 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE session; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.session IS 'PCEP session state (pola session), keyed by PCC OOB address.';


--
-- TOC entry 3780 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN session.caps; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.session.caps IS 'Negotiated capabilities JSON array, e.g. ["Stateful","Update","Instantiation","Color","SR-TE","SRv6-TE"].';


--
-- TOC entry 3781 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN session.stateful; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.session.stateful IS 'GENERATED quick filter: caps contains "Stateful".';


--
-- TOC entry 3782 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN session.instantiation; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.session.instantiation IS 'GENERATED quick filter: caps contains "Instantiation".';


--
-- TOC entry 3783 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN session.sr_te; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.session.sr_te IS 'GENERATED quick filter: caps contains "SR-TE".';


--
-- TOC entry 3784 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN session.srv6_te; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.session.srv6_te IS 'GENERATED quick filter: caps contains "SRv6-TE".';


--
-- TOC entry 233 (class 1259 OID 58543)
-- Name: session_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.session ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 245 (class 1259 OID 58711)
-- Name: snapshot; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.snapshot (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    taken_at timestamp with time zone DEFAULT now() NOT NULL,
    node_count integer DEFAULT 0 NOT NULL,
    link_count integer DEFAULT 0 NOT NULL,
    hash text
);


ALTER TABLE public.snapshot OWNER TO root;

--
-- TOC entry 3785 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE snapshot; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.snapshot IS 'Immutable poll snapshot header (every poll_interval). TimescaleDB hypertable on taken_at.';


--
-- TOC entry 3786 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN snapshot.hash; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.snapshot.hash IS 'Content hash of the poll; equal hash => no change => diff engine can skip.';


--
-- TOC entry 244 (class 1259 OID 58710)
-- Name: snapshot_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.snapshot ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.snapshot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 249 (class 1259 OID 58737)
-- Name: snapshot_link; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.snapshot_link (
    id bigint NOT NULL,
    snapshot_id bigint NOT NULL,
    taken_at timestamp with time zone NOT NULL,
    local_ip inet NOT NULL,
    remote_ip inet NOT NULL,
    igp_metric integer,
    te_metric integer,
    delay_us integer,
    max_bw_bps bigint,
    admin_group integer,
    adj_sid integer,
    status public.discovery_status,
    data_quality text[]
);


ALTER TABLE public.snapshot_link OWNER TO root;

--
-- TOC entry 3787 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE snapshot_link; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.snapshot_link IS 'Per-poll full metric set per link -> powers metric-change history, time-travel topology, diff engine. Hypertable on taken_at.';


--
-- TOC entry 248 (class 1259 OID 58736)
-- Name: snapshot_link_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.snapshot_link ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.snapshot_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 247 (class 1259 OID 58728)
-- Name: snapshot_node; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.snapshot_node (
    id bigint NOT NULL,
    snapshot_id bigint NOT NULL,
    taken_at timestamp with time zone NOT NULL,
    system_id text NOT NULL,
    hostname text,
    router_id inet,
    status public.discovery_status
);


ALTER TABLE public.snapshot_node OWNER TO root;

--
-- TOC entry 3788 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE snapshot_node; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.snapshot_node IS 'Per-poll node projection (time-travel topology). FK-by-value to snapshot (hypertable cannot be FK target by id alone).';


--
-- TOC entry 246 (class 1259 OID 58727)
-- Name: snapshot_node_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.snapshot_node ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.snapshot_node_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 252 (class 1259 OID 58782)
-- Name: telemetry_sample; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.telemetry_sample (
    ts timestamp with time zone NOT NULL,
    link_id bigint NOT NULL,
    rx_bps bigint DEFAULT 0 NOT NULL,
    tx_bps bigint DEFAULT 0 NOT NULL,
    utilization_pct numeric(5,2) DEFAULT 0 NOT NULL,
    congested boolean DEFAULT false NOT NULL
);


ALTER TABLE public.telemetry_sample OWNER TO root;

--
-- TOC entry 3789 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE telemetry_sample; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.telemetry_sample IS 'Interface counters / utilization (UC-10). TimescaleDB hypertable on ts; aggs telemetry_5m / telemetry_1h.';


--
-- TOC entry 3790 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN telemetry_sample.utilization_pct; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.telemetry_sample.utilization_pct IS 'tx_bps / link.max_bw_bps * 100.';


--
-- TOC entry 3791 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN telemetry_sample.congested; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.telemetry_sample.congested IS 'True when utilization_pct > 80 (congestion threshold).';


--
-- TOC entry 230 (class 1259 OID 58514)
-- Name: user_account; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public.user_account (
    id bigint NOT NULL,
    email text NOT NULL,
    role public.user_role DEFAULT 'viewer'::public.user_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_account OWNER TO root;

--
-- TOC entry 3792 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE user_account; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON TABLE public.user_account IS 'Console users; role gates write actions (viewer<operator<admin).';


--
-- TOC entry 3793 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN user_account.role; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON COLUMN public.user_account.role IS 'viewer (read), operator (writes), admin (config + READ_ONLY/reopt toggles).';


--
-- TOC entry 229 (class 1259 OID 58513)
-- Name: user_account_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

ALTER TABLE public.user_account ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.user_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 259 (class 1259 OID 58840)
-- Name: v_data_quality; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_data_quality AS
 SELECT l.id AS link_id,
    l.network_id,
    nl.hostname AS local_hostname,
    nr.hostname AS remote_hostname,
    l.local_ip,
    l.remote_ip,
    l.igp_metric,
    l.te_metric,
    l.delay_us,
    l.admin_group,
    l.data_quality
   FROM ((public.link l
     JOIN public.node nl ON ((nl.id = l.local_node_id)))
     JOIN public.node nr ON ((nr.id = l.remote_node_id)))
  WHERE (array_length(l.data_quality, 1) IS NOT NULL);


ALTER VIEW public.v_data_quality OWNER TO root;

--
-- TOC entry 3794 (class 0 OID 0)
-- Dependencies: 259
-- Name: VIEW v_data_quality; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_data_quality IS 'UC-01 data-quality panel: links with non-empty data_quality (e.g. R3->R2, R3->R4 missing_te/missing_delay).';


--
-- TOC entry 257 (class 1259 OID 58831)
-- Name: v_link_capacity; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_link_capacity AS
 SELECT l.id AS link_id,
    l.network_id,
    l.local_ip,
    l.remote_ip,
    l.local_node_id,
    l.remote_node_id,
    l.status,
    l.max_bw_bps,
    COALESCE(r.reserved_bps, (0)::numeric) AS reserved_bps,
    ((l.max_bw_bps)::numeric - COALESCE(r.reserved_bps, (0)::numeric)) AS available_bps,
        CASE
            WHEN ((l.max_bw_bps IS NULL) OR (l.max_bw_bps = 0)) THEN NULL::numeric
            ELSE round(((COALESCE(r.reserved_bps, (0)::numeric) / (l.max_bw_bps)::numeric) * (100)::numeric), 2)
        END AS utilization_pct
   FROM (public.link l
     LEFT JOIN ( SELECT reservation.link_id,
            sum(reservation.reserved_bps) AS reserved_bps
           FROM public.reservation
          GROUP BY reservation.link_id) r ON ((r.link_id = l.id)));


ALTER VIEW public.v_link_capacity OWNER TO root;

--
-- TOC entry 3795 (class 0 OID 0)
-- Dependencies: 257
-- Name: VIEW v_link_capacity; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_link_capacity IS 'UC-08/10: max_bw_bps - SUM(reserved) = available, plus reservation-based utilization. Reservable BW comes from the ledger only.';


--
-- TOC entry 261 (class 1259 OID 58850)
-- Name: v_kpi; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_kpi AS
 SELECT id AS network_id,
    ( SELECT count(*) AS count
           FROM public.session s
          WHERE ((s.network_id = net.id) AND (s.state = 'up'::public.session_state))) AS pcep_up,
    ( SELECT count(*) AS count
           FROM public.policy p
          WHERE ((p.network_id = net.id) AND (p.status = 'up'::public.policy_status))) AS active_lsps,
    ( SELECT count(*) AS count
           FROM public.service sv
          WHERE (sv.network_id = net.id)) AS services,
    ( SELECT count(DISTINCT vc.link_id) AS count
           FROM public.v_link_capacity vc
          WHERE ((vc.network_id = net.id) AND (vc.utilization_pct IS NOT NULL) AND (vc.utilization_pct > (80)::numeric))) AS congested_links,
    ( SELECT count(*) AS count
           FROM public.policy p
          WHERE ((p.network_id = net.id) AND (p.status = 'down'::public.policy_status))) AS policies_down
   FROM public.network net;


ALTER VIEW public.v_kpi OWNER TO root;

--
-- TOC entry 3796 (class 0 OID 0)
-- Dependencies: 261
-- Name: VIEW v_kpi; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_kpi IS 'Single-row-per-network KPI bar: pcep_up, active_lsps, services, congested_links (reservation utilization > 80%), policies_down.';


--
-- TOC entry 256 (class 1259 OID 58826)
-- Name: v_link_pair; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_link_pair AS
 SELECT a.network_id,
    a.id AS a_link_id,
    b.id AS b_link_id,
    a.local_node_id AS a_node_id,
    b.local_node_id AS b_node_id,
    a.local_ip AS a_ip,
    b.local_ip AS b_ip,
    na.hostname AS a_hostname,
    nb.hostname AS b_hostname,
    a.igp_metric AS ab_igp_metric,
    a.te_metric AS ab_te_metric,
    a.delay_us AS ab_delay_us,
    a.admin_group AS ab_admin_group,
    a.adj_sid AS ab_adj_sid,
    a.status AS ab_status,
    a.data_quality AS ab_data_quality,
    b.igp_metric AS ba_igp_metric,
    b.te_metric AS ba_te_metric,
    b.delay_us AS ba_delay_us,
    b.admin_group AS ba_admin_group,
    b.adj_sid AS ba_adj_sid,
    b.status AS ba_status,
    b.data_quality AS ba_data_quality,
    a.max_bw_bps,
    (a.sim_failed OR b.sim_failed) AS sim_failed,
    ((a.status = 'up'::public.discovery_status) AND (b.status = 'up'::public.discovery_status)) AS edge_up,
    ((array_length(a.data_quality, 1) IS NOT NULL) OR (array_length(b.data_quality, 1) IS NOT NULL)) AS has_data_gap
   FROM (((public.link a
     JOIN public.link b ON (((a.network_id = b.network_id) AND (a.local_ip = b.remote_ip) AND (a.remote_ip = b.local_ip) AND (a.local_node_id = b.remote_node_id))))
     JOIN public.node na ON ((na.id = a.local_node_id)))
     JOIN public.node nb ON ((nb.id = b.local_node_id)))
  WHERE (a.local_ip < b.local_ip);


ALTER VIEW public.v_link_pair OWNER TO root;

--
-- TOC entry 3797 (class 0 OID 0)
-- Dependencies: 256
-- Name: VIEW v_link_pair; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_link_pair IS 'Collapses 2 directed link rows into one A<->B edge with per-direction metrics (canvas). 14 directed rows -> 7 edges.';


--
-- TOC entry 258 (class 1259 OID 58836)
-- Name: v_orphan_lsp; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_orphan_lsp AS
 SELECT id,
    network_id,
    name,
    color,
    src_addr,
    dst_addr,
    pcep_session_addr,
    status,
    headend_up
   FROM public.policy p
  WHERE (headend_up = false);


ALTER VIEW public.v_orphan_lsp OWNER TO root;

--
-- TOC entry 3798 (class 0 OID 0)
-- Dependencies: 258
-- Name: VIEW v_orphan_lsp; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_orphan_lsp IS 'UC-02: policies with headend_up = false (LSP without a live head-end session).';


--
-- TOC entry 260 (class 1259 OID 58845)
-- Name: v_topology_current; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.v_topology_current AS
 SELECT 'node'::text AS kind,
    n.network_id,
    n.id AS object_id,
    n.hostname AS label,
    n.system_id,
    host(n.router_id) AS router_id,
    n.node_sid,
    (n.status)::text AS status,
    NULL::inet AS local_ip,
    NULL::inet AS remote_ip,
    NULL::integer AS igp_metric,
    NULL::integer AS te_metric,
    NULL::integer AS delay_us,
    NULL::integer AS admin_group,
    NULL::integer AS adj_sid,
    NULL::bigint AS max_bw_bps,
    '{}'::text[] AS data_quality
   FROM public.node n
UNION ALL
 SELECT 'link'::text AS kind,
    l.network_id,
    l.id AS object_id,
    ((nl.hostname || '->'::text) || nr.hostname) AS label,
    NULL::text AS system_id,
    NULL::text AS router_id,
    NULL::integer AS node_sid,
    (l.status)::text AS status,
    l.local_ip,
    l.remote_ip,
    l.igp_metric,
    l.te_metric,
    l.delay_us,
    l.admin_group,
    l.adj_sid,
    l.max_bw_bps,
    l.data_quality
   FROM ((public.link l
     JOIN public.node nl ON ((nl.id = l.local_node_id)))
     JOIN public.node nr ON ((nr.id = l.remote_node_id)));


ALTER VIEW public.v_topology_current OWNER TO root;

--
-- TOC entry 3799 (class 0 OID 0)
-- Dependencies: 260
-- Name: VIEW v_topology_current; Type: COMMENT; Schema: public; Owner: root
--

COMMENT ON VIEW public.v_topology_current IS 'Latest nodes+links+status for GET /api/topology (kind = node|link union).';


--
-- TOC entry 3490 (class 2606 OID 58534)
-- Name: api_token api_token_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.api_token
    ADD CONSTRAINT api_token_pkey PRIMARY KEY (id);


--
-- TOC entry 3492 (class 2606 OID 58536)
-- Name: api_token api_token_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.api_token
    ADD CONSTRAINT api_token_token_hash_key UNIQUE (token_hash);


--
-- TOC entry 3536 (class 2606 OID 58808)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- TOC entry 3531 (class 2606 OID 58755)
-- Name: event event_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id, ts);


--
-- TOC entry 3473 (class 2606 OID 58459)
-- Name: link link_local_ip_uq; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link
    ADD CONSTRAINT link_local_ip_uq UNIQUE (network_id, local_ip);


--
-- TOC entry 3480 (class 2606 OID 58485)
-- Name: link_metric_history link_metric_history_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link_metric_history
    ADD CONSTRAINT link_metric_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3475 (class 2606 OID 58457)
-- Name: link link_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link
    ADD CONSTRAINT link_pkey PRIMARY KEY (id);


--
-- TOC entry 3456 (class 2606 OID 58399)
-- Name: network network_name_key; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.network
    ADD CONSTRAINT network_name_key UNIQUE (name);


--
-- TOC entry 3458 (class 2606 OID 58397)
-- Name: network network_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.network
    ADD CONSTRAINT network_pkey PRIMARY KEY (id);


--
-- TOC entry 3462 (class 2606 OID 58413)
-- Name: node node_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node
    ADD CONSTRAINT node_pkey PRIMARY KEY (id);


--
-- TOC entry 3484 (class 2606 OID 58500)
-- Name: node_srlg node_srlg_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node_srlg
    ADD CONSTRAINT node_srlg_pkey PRIMARY KEY (id);


--
-- TOC entry 3464 (class 2606 OID 58415)
-- Name: node node_system_id_uq; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node
    ADD CONSTRAINT node_system_id_uq UNIQUE (network_id, system_id);


--
-- TOC entry 3511 (class 2606 OID 58639)
-- Name: policy_link policy_link_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_link
    ADD CONSTRAINT policy_link_pkey PRIMARY KEY (policy_id, link_id);


--
-- TOC entry 3505 (class 2606 OID 58616)
-- Name: policy_path_hop policy_path_hop_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_path_hop
    ADD CONSTRAINT policy_path_hop_pkey PRIMARY KEY (id);


--
-- TOC entry 3508 (class 2606 OID 58618)
-- Name: policy_path_hop policy_path_hop_uq; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_path_hop
    ADD CONSTRAINT policy_path_hop_uq UNIQUE (policy_id, seq);


--
-- TOC entry 3503 (class 2606 OID 58587)
-- Name: policy policy_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_pkey PRIMARY KEY (id);


--
-- TOC entry 3467 (class 2606 OID 58434)
-- Name: prefix prefix_node_uq; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.prefix
    ADD CONSTRAINT prefix_node_uq UNIQUE (node_id, prefix);


--
-- TOC entry 3469 (class 2606 OID 58432)
-- Name: prefix prefix_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.prefix
    ADD CONSTRAINT prefix_pkey PRIMARY KEY (id);


--
-- TOC entry 3518 (class 2606 OID 58697)
-- Name: reservation reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_pkey PRIMARY KEY (id);


--
-- TOC entry 3514 (class 2606 OID 58660)
-- Name: service service_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_pkey PRIMARY KEY (id);


--
-- TOC entry 3496 (class 2606 OID 58560)
-- Name: session session_pcc_uq; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pcc_uq UNIQUE (network_id, pcc_addr);


--
-- TOC entry 3498 (class 2606 OID 58558)
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- TOC entry 3528 (class 2606 OID 58743)
-- Name: snapshot_link snapshot_link_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.snapshot_link
    ADD CONSTRAINT snapshot_link_pkey PRIMARY KEY (id, taken_at);


--
-- TOC entry 3525 (class 2606 OID 58734)
-- Name: snapshot_node snapshot_node_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.snapshot_node
    ADD CONSTRAINT snapshot_node_pkey PRIMARY KEY (id);


--
-- TOC entry 3522 (class 2606 OID 58720)
-- Name: snapshot snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.snapshot
    ADD CONSTRAINT snapshot_pkey PRIMARY KEY (id, taken_at);


--
-- TOC entry 3533 (class 2606 OID 58790)
-- Name: telemetry_sample telemetry_sample_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.telemetry_sample
    ADD CONSTRAINT telemetry_sample_pkey PRIMARY KEY (link_id, ts);


--
-- TOC entry 3486 (class 2606 OID 58524)
-- Name: user_account user_account_email_key; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_email_key UNIQUE (email);


--
-- TOC entry 3488 (class 2606 OID 58522)
-- Name: user_account user_account_pkey; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_pkey PRIMARY KEY (id);


--
-- TOC entry 3493 (class 1259 OID 58542)
-- Name: api_token_user_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX api_token_user_idx ON public.api_token USING btree (user_id);


--
-- TOC entry 3537 (class 1259 OID 58814)
-- Name: audit_log_ts_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX audit_log_ts_idx ON public.audit_log USING btree (ts DESC);


--
-- TOC entry 3538 (class 1259 OID 58815)
-- Name: audit_log_user_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX audit_log_user_idx ON public.audit_log USING btree (user_id, ts DESC);


--
-- TOC entry 3529 (class 1259 OID 58781)
-- Name: event_network_type_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX event_network_type_idx ON public.event USING btree (network_id, type, ts DESC);


--
-- TOC entry 3539 (class 1259 OID 58825)
-- Name: health_metric_ts_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX health_metric_ts_idx ON public.health_metric USING btree (network_id, ts DESC);


--
-- TOC entry 3470 (class 1259 OID 58478)
-- Name: link_data_quality_gin; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX link_data_quality_gin ON public.link USING gin (data_quality);


--
-- TOC entry 3471 (class 1259 OID 58475)
-- Name: link_endpoints_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX link_endpoints_idx ON public.link USING btree (local_node_id, remote_node_id);


--
-- TOC entry 3478 (class 1259 OID 58491)
-- Name: link_metric_history_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX link_metric_history_idx ON public.link_metric_history USING btree (link_id, changed_at DESC);


--
-- TOC entry 3476 (class 1259 OID 58476)
-- Name: link_remote_ip_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX link_remote_ip_idx ON public.link USING btree (network_id, remote_ip);


--
-- TOC entry 3477 (class 1259 OID 58477)
-- Name: link_up_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX link_up_idx ON public.link USING btree (network_id) WHERE (status = 'up'::public.discovery_status);


--
-- TOC entry 3459 (class 1259 OID 58422)
-- Name: node_network_hostname_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX node_network_hostname_idx ON public.node USING btree (network_id, hostname);


--
-- TOC entry 3460 (class 1259 OID 58421)
-- Name: node_network_router_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX node_network_router_idx ON public.node USING btree (network_id, router_id);


--
-- TOC entry 3481 (class 1259 OID 58512)
-- Name: node_srlg_link_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX node_srlg_link_idx ON public.node_srlg USING btree (link_id) WHERE (link_id IS NOT NULL);


--
-- TOC entry 3482 (class 1259 OID 58511)
-- Name: node_srlg_node_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX node_srlg_node_idx ON public.node_srlg USING btree (node_id) WHERE (node_id IS NOT NULL);


--
-- TOC entry 3499 (class 1259 OID 58609)
-- Name: policy_color_dst_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX policy_color_dst_idx ON public.policy USING btree (network_id, color, dst_addr);


--
-- TOC entry 3509 (class 1259 OID 58650)
-- Name: policy_link_link_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX policy_link_link_idx ON public.policy_link USING btree (link_id);


--
-- TOC entry 3500 (class 1259 OID 58608)
-- Name: policy_network_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX policy_network_idx ON public.policy USING btree (network_id);


--
-- TOC entry 3501 (class 1259 OID 58610)
-- Name: policy_orphan_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX policy_orphan_idx ON public.policy USING btree (network_id) WHERE (headend_up = false);


--
-- TOC entry 3506 (class 1259 OID 58634)
-- Name: policy_path_hop_policy_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX policy_path_hop_policy_idx ON public.policy_path_hop USING btree (policy_id, seq);


--
-- TOC entry 3465 (class 1259 OID 58440)
-- Name: prefix_node_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX prefix_node_idx ON public.prefix USING btree (node_id);


--
-- TOC entry 3516 (class 1259 OID 58708)
-- Name: reservation_link_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX reservation_link_idx ON public.reservation USING btree (link_id);


--
-- TOC entry 3519 (class 1259 OID 58709)
-- Name: reservation_policy_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX reservation_policy_idx ON public.reservation USING btree (policy_id);


--
-- TOC entry 3512 (class 1259 OID 58686)
-- Name: service_network_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX service_network_idx ON public.service USING btree (network_id);


--
-- TOC entry 3515 (class 1259 OID 58687)
-- Name: service_policy_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX service_policy_idx ON public.service USING btree (policy_id);


--
-- TOC entry 3494 (class 1259 OID 58571)
-- Name: session_node_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX session_node_idx ON public.session USING btree (node_id);


--
-- TOC entry 3526 (class 1259 OID 58744)
-- Name: snapshot_link_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX snapshot_link_idx ON public.snapshot_link USING btree (snapshot_id, taken_at DESC);


--
-- TOC entry 3520 (class 1259 OID 58726)
-- Name: snapshot_network_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX snapshot_network_idx ON public.snapshot USING btree (network_id, taken_at DESC);


--
-- TOC entry 3523 (class 1259 OID 58735)
-- Name: snapshot_node_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX snapshot_node_idx ON public.snapshot_node USING btree (snapshot_id);


--
-- TOC entry 3534 (class 1259 OID 58796)
-- Name: telemetry_sample_ts_idx; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX telemetry_sample_ts_idx ON public.telemetry_sample USING btree (ts DESC);


--
-- TOC entry 3548 (class 2606 OID 58537)
-- Name: api_token api_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.api_token
    ADD CONSTRAINT api_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON DELETE CASCADE;


--
-- TOC entry 3574 (class 2606 OID 58809)
-- Name: audit_log audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id);


--
-- TOC entry 3568 (class 2606 OID 58776)
-- Name: event event_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES public.user_account(id);


--
-- TOC entry 3569 (class 2606 OID 58761)
-- Name: event event_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE SET NULL;


--
-- TOC entry 3570 (class 2606 OID 58756)
-- Name: event event_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3571 (class 2606 OID 58766)
-- Name: event event_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id) ON DELETE SET NULL;


--
-- TOC entry 3572 (class 2606 OID 58771)
-- Name: event event_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.policy(id) ON DELETE SET NULL;


--
-- TOC entry 3575 (class 2606 OID 58820)
-- Name: health_metric health_metric_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.health_metric
    ADD CONSTRAINT health_metric_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3542 (class 2606 OID 58465)
-- Name: link link_local_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link
    ADD CONSTRAINT link_local_node_id_fkey FOREIGN KEY (local_node_id) REFERENCES public.node(id);


--
-- TOC entry 3545 (class 2606 OID 58486)
-- Name: link_metric_history link_metric_history_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link_metric_history
    ADD CONSTRAINT link_metric_history_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE CASCADE;


--
-- TOC entry 3543 (class 2606 OID 58460)
-- Name: link link_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link
    ADD CONSTRAINT link_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3544 (class 2606 OID 58470)
-- Name: link link_remote_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.link
    ADD CONSTRAINT link_remote_node_id_fkey FOREIGN KEY (remote_node_id) REFERENCES public.node(id);


--
-- TOC entry 3540 (class 2606 OID 58416)
-- Name: node node_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node
    ADD CONSTRAINT node_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3546 (class 2606 OID 58506)
-- Name: node_srlg node_srlg_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node_srlg
    ADD CONSTRAINT node_srlg_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE CASCADE;


--
-- TOC entry 3547 (class 2606 OID 58501)
-- Name: node_srlg node_srlg_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.node_srlg
    ADD CONSTRAINT node_srlg_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id) ON DELETE CASCADE;


--
-- TOC entry 3551 (class 2606 OID 58603)
-- Name: policy policy_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user_account(id);


--
-- TOC entry 3552 (class 2606 OID 58598)
-- Name: policy policy_dst_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_dst_node_id_fkey FOREIGN KEY (dst_node_id) REFERENCES public.node(id);


--
-- TOC entry 3558 (class 2606 OID 58645)
-- Name: policy_link policy_link_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_link
    ADD CONSTRAINT policy_link_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE CASCADE;


--
-- TOC entry 3559 (class 2606 OID 58640)
-- Name: policy_link policy_link_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_link
    ADD CONSTRAINT policy_link_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.policy(id) ON DELETE CASCADE;


--
-- TOC entry 3553 (class 2606 OID 58588)
-- Name: policy policy_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3555 (class 2606 OID 58629)
-- Name: policy_path_hop policy_path_hop_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_path_hop
    ADD CONSTRAINT policy_path_hop_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id);


--
-- TOC entry 3556 (class 2606 OID 58624)
-- Name: policy_path_hop policy_path_hop_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_path_hop
    ADD CONSTRAINT policy_path_hop_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id);


--
-- TOC entry 3557 (class 2606 OID 58619)
-- Name: policy_path_hop policy_path_hop_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy_path_hop
    ADD CONSTRAINT policy_path_hop_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.policy(id) ON DELETE CASCADE;


--
-- TOC entry 3554 (class 2606 OID 58593)
-- Name: policy policy_src_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_src_node_id_fkey FOREIGN KEY (src_node_id) REFERENCES public.node(id);


--
-- TOC entry 3541 (class 2606 OID 58435)
-- Name: prefix prefix_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.prefix
    ADD CONSTRAINT prefix_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id) ON DELETE CASCADE;


--
-- TOC entry 3565 (class 2606 OID 58698)
-- Name: reservation reservation_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE CASCADE;


--
-- TOC entry 3566 (class 2606 OID 58703)
-- Name: reservation reservation_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.policy(id) ON DELETE SET NULL;


--
-- TOC entry 3560 (class 2606 OID 58681)
-- Name: service service_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user_account(id);


--
-- TOC entry 3561 (class 2606 OID 58671)
-- Name: service service_egress_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_egress_node_id_fkey FOREIGN KEY (egress_node_id) REFERENCES public.node(id);


--
-- TOC entry 3562 (class 2606 OID 58666)
-- Name: service service_ingress_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_ingress_node_id_fkey FOREIGN KEY (ingress_node_id) REFERENCES public.node(id);


--
-- TOC entry 3563 (class 2606 OID 58661)
-- Name: service service_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3564 (class 2606 OID 58676)
-- Name: service service_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.policy(id);


--
-- TOC entry 3549 (class 2606 OID 58561)
-- Name: session session_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3550 (class 2606 OID 58566)
-- Name: session session_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id);


--
-- TOC entry 3567 (class 2606 OID 58721)
-- Name: snapshot snapshot_network_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.snapshot
    ADD CONSTRAINT snapshot_network_id_fkey FOREIGN KEY (network_id) REFERENCES public.network(id) ON DELETE CASCADE;


--
-- TOC entry 3573 (class 2606 OID 58791)
-- Name: telemetry_sample telemetry_sample_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public.telemetry_sample
    ADD CONSTRAINT telemetry_sample_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.link(id) ON DELETE CASCADE;


-- Completed on 2026-06-16 12:51:46 IST

--
-- PostgreSQL database dump complete
--

\unrestrict PzjpspHDhwsXBk30UOHupjhKcuZ2wVT8TxJFP0hiNXdqpFFeUGLUhhM3iKuuikm

