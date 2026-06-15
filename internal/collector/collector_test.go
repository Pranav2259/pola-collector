package collector

import (
	"encoding/json"
	"os"
	"os/exec"
	"testing"

	"github.com/pola-collector/internal/models"
)

// ─── TED parsing tests ────────────────────────────────────────────────────────

// realTEDOutput is exactly what `pola ted -j` emits from the live binary.
const realTEDOutput = `{"ted":[{"asn":65001,"hostname":"R1-PE","isisAreaID":"49.0001","links":[{"adjSid":24003,"localIP":"10.1.15.1","metrics":[{"type":"METRIC_TYPE_IGP","value":10},{"type":"METRIC_TYPE_TE","value":10},{"type":"METRIC_TYPE_DELAY","value":4200}],"remoteIP":"10.1.15.2","remoteNode":"0000.0000.0005"},{"adjSid":24001,"localIP":"10.1.12.1","metrics":[{"type":"METRIC_TYPE_IGP","value":10},{"type":"METRIC_TYPE_TE","value":10},{"type":"METRIC_TYPE_DELAY","value":2500}],"remoteIP":"10.1.12.2","remoteNode":"0000.0000.0002"}],"prefixes":[{"prefix":"10.1.15.0/30"},{"prefix":"10.0.0.1/32","sidIndex":1},{"prefix":"10.1.12.0/30"}],"routerID":"0000.0000.0001","srgbBegin":16000,"srgbEnd":24000,"srv6SIDs":[]}]}`

// wrappedTEDOutput is the format used in the sample JSON files (with command/output envelope).
const wrappedTEDOutput = `{"command":"./pola ted -j -p 50052","output":{"ted":[{"asn":65001,"hostname":"R1-PE","isisAreaID":"49.0001","links":[],"prefixes":[{"prefix":"10.0.0.1/32","sidIndex":1}],"routerID":"0000.0000.0001","srgbBegin":16000,"srgbEnd":24000,"srv6SIDs":[]}]}}`

func TestParseTED_DirectFormat(t *testing.T) {
	var direct models.TEDDirect
	if err := json.Unmarshal([]byte(realTEDOutput), &direct); err != nil {
		t.Fatalf("unmarshal direct TED failed: %v", err)
	}
	if len(direct.Nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(direct.Nodes))
	}
	n := direct.Nodes[0]
	if n.Hostname != "R1-PE" {
		t.Errorf("hostname: got %q, want %q", n.Hostname, "R1-PE")
	}
	if len(n.Links) != 2 {
		t.Errorf("links: got %d, want 2", len(n.Links))
	}
	if n.Links[0].Metrics[2].Value != 4200 {
		t.Errorf("delay metric: got %d, want 4200", n.Links[0].Metrics[2].Value)
	}
}

func TestParseTED_WrappedFormat(t *testing.T) {
	var wrapped models.TEDOutput
	if err := json.Unmarshal([]byte(wrappedTEDOutput), &wrapped); err != nil {
		t.Fatalf("unmarshal wrapped TED failed: %v", err)
	}
	if len(wrapped.Output.Nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(wrapped.Output.Nodes))
	}
}

// ─── Session parsing tests ────────────────────────────────────────────────────

// realSessionOutput is the exact output of `pola session -j` from the live binary.
const realSessionOutput = `[{"Addr":"192.168.232.1","State":"SESSION_STATE_UP","Caps":["Stateful","Update","Instantiation","Color","unknown_type_27","SR-TE","SRv6-TE","unknown_type_73"],"IsSynced":true},{"Addr":"192.168.232.5","State":"SESSION_STATE_UP","Caps":["Stateful","Update","Instantiation","Color","unknown_type_27","SR-TE","SRv6-TE","unknown_type_73"],"IsSynced":true},{"Addr":"192.168.232.2","State":"SESSION_STATE_UP","Caps":["Stateful","Update","Instantiation","Color","unknown_type_27","SR-TE","SRv6-TE","unknown_type_73"],"IsSynced":true},{"Addr":"192.168.232.4","State":"SESSION_STATE_UP","Caps":["Stateful","Update","Instantiation","Color","unknown_type_27","SR-TE","SRv6-TE","unknown_type_73"],"IsSynced":true},{"Addr":"192.168.232.3","State":"SESSION_STATE_UP","Caps":["Stateful","Update","Instantiation","Color","unknown_type_27","SR-TE","SRv6-TE","unknown_type_73"],"IsSynced":true}]`

const wrappedSessionOutput = `{"command":"./pola session -j -p 50052","output":[{"Addr":"192.168.232.1","State":"SESSION_STATE_UP","Caps":["Stateful"],"IsSynced":true}]}`

func TestParseSession_DirectFormat(t *testing.T) {
	var sessions []models.Session
	if err := json.Unmarshal([]byte(realSessionOutput), &sessions); err != nil {
		t.Fatalf("unmarshal direct sessions failed: %v", err)
	}
	if len(sessions) != 5 {
		t.Fatalf("expected 5 sessions, got %d", len(sessions))
	}

	// Verify all peers are UP and synced
	for _, s := range sessions {
		if s.State != "SESSION_STATE_UP" {
			t.Errorf("peer %s: state=%q, want SESSION_STATE_UP", s.Addr, s.State)
		}
		if !s.IsSynced {
			t.Errorf("peer %s: expected IsSynced=true", s.Addr)
		}
	}

	// Verify the exact 8 caps on the first peer (including unknown types)
	wantCaps := []string{
		"Stateful", "Update", "Instantiation", "Color",
		"unknown_type_27", "SR-TE", "SRv6-TE", "unknown_type_73",
	}
	got := sessions[0].Caps
	if len(got) != len(wantCaps) {
		t.Fatalf("caps count: got %d, want %d — caps: %v", len(got), len(wantCaps), got)
	}
	for i, c := range wantCaps {
		if got[i] != c {
			t.Errorf("caps[%d]: got %q, want %q", i, got[i], c)
		}
	}

	// Verify all 5 expected peer addresses are present
	wantAddrs := map[string]bool{
		"192.168.232.1": false,
		"192.168.232.2": false,
		"192.168.232.3": false,
		"192.168.232.4": false,
		"192.168.232.5": false,
	}
	for _, s := range sessions {
		if _, ok := wantAddrs[s.Addr]; !ok {
			t.Errorf("unexpected addr %q in sessions", s.Addr)
		}
		wantAddrs[s.Addr] = true
	}
	for addr, seen := range wantAddrs {
		if !seen {
			t.Errorf("expected addr %q not found in sessions", addr)
		}
	}
}

func TestParseSession_WrappedFormat(t *testing.T) {
	var wrapped models.SessionOutput
	if err := json.Unmarshal([]byte(wrappedSessionOutput), &wrapped); err != nil {
		t.Fatalf("unmarshal wrapped sessions failed: %v", err)
	}
	if len(wrapped.Output) != 1 {
		t.Fatalf("expected 1 session, got %d", len(wrapped.Output))
	}
}

// ─── Integration: CollectTED with a fake binary ───────────────────────────────

// TestCollectTED_RealBinaryFormat uses a tiny shell script as the "pola" binary
// to emit the real format, then confirms CollectTED parses it.
func TestCollectTED_RealBinaryFormat(t *testing.T) {
	if _, err := exec.LookPath("sh"); err != nil {
		t.Skip("sh not available")
	}

	// Write a fake pola script that echoes the real output format
	script := `#!/bin/sh
echo '` + realTEDOutput + `'`
	f, err := os.CreateTemp("", "fakepola-*.sh")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(f.Name())
	if _, err := f.WriteString(script); err != nil {
		t.Fatal(err)
	}
	f.Close()
	os.Chmod(f.Name(), 0755)

	cfg := Config{Binary: f.Name(), Port: "50052"}
	nodes, _, err := CollectTED(cfg)
	if err != nil {
		t.Fatalf("CollectTED failed: %v", err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(nodes))
	}
	if nodes[0].Hostname != "R1-PE" {
		t.Errorf("hostname: got %q, want R1-PE", nodes[0].Hostname)
	}
}
