package collector

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/pola-collector/internal/models"
)

// Config holds everything needed to run pola commands.
type Config struct {
	Binary string // path to pola binary, e.g. "./pola"
	Port   string // gRPC port, e.g. "50052"
	Host   string // gRPC host, e.g. "localhost"
}

// CollectSessions runs `pola session -j` and returns parsed results.
//
// The real pola binary emits:  [{...},{...}]          (plain JSON array)
// Sample/test JSON files emit: {"command":"...","output":[...]}
// Both are handled; the direct array is tried first.
func CollectSessions(cfg Config) ([]models.Session, string, error) {
	args := buildArgs(cfg, "session")
	out, rawCmd, err := run(cfg.Binary, args)
	if err != nil {
		return nil, rawCmd, fmt.Errorf("pola session: %w", err)
	}

	// ── Try direct array first: [{...},...] ──────────────────────────────
	var direct []models.Session
	if err := json.Unmarshal(out, &direct); err == nil && len(direct) > 0 {
		return direct, rawCmd, nil
	}

	// ── Fall back to wrapped format: {"command":...,"output":[...]} ──────
	var wrapped models.SessionOutput
	if err := json.Unmarshal(out, &wrapped); err == nil && len(wrapped.Output) > 0 {
		return wrapped.Output, rawCmd, nil
	}

	return nil, rawCmd, fmt.Errorf("parse session JSON: no sessions found in output: %s", truncate(out, 200))
}

// CollectTED runs `pola ted -j` and returns parsed results.
//
// The real pola binary emits:  {"ted":[...]}
// Sample/test JSON files emit: {"command":"...","output":{"ted":[...]}}
// Both are handled; the direct format is tried first.
func CollectTED(cfg Config) ([]models.TEDNode, string, error) {
	args := buildArgs(cfg, "ted")
	out, rawCmd, err := run(cfg.Binary, args)
	if err != nil {
		return nil, rawCmd, fmt.Errorf("pola ted: %w", err)
	}

	// ── Try direct format first: {"ted":[...]} ────────────────────────────
	var direct models.TEDDirect
	if err := json.Unmarshal(out, &direct); err == nil && len(direct.Nodes) > 0 {
		return direct.Nodes, rawCmd, nil
	}

	// ── Fall back to wrapped format: {"command":...,"output":{"ted":[...]}}
	var wrapped models.TEDOutput
	if err := json.Unmarshal(out, &wrapped); err == nil && len(wrapped.Output.Nodes) > 0 {
		return wrapped.Output.Nodes, rawCmd, nil
	}

	// ── Both succeeded structurally but returned 0 nodes — report raw output
	return nil, rawCmd, fmt.Errorf("parse TED JSON: no nodes found in output: %s", truncate(out, 200))
}

// ─── internal helpers ────────────────────────────────────────────────────────

func buildArgs(cfg Config, subCmd string) []string {
	args := []string{subCmd, "-j"}
	if cfg.Port != "" {
		args = append(args, "-p", cfg.Port)
	}
	if cfg.Host != "" {
		args = append(args, "-d", cfg.Host)
	}
	return args
}

func run(binary string, args []string) ([]byte, string, error) {
	cmd := exec.Command(binary, args...)
	rawCmd := binary + " " + strings.Join(args, " ")
	out, err := cmd.Output()
	if err != nil {
		// include stderr in error message for easier debugging
		var exitErr *exec.ExitError
		stderr := ""
		if exitErr, _ = err.(*exec.ExitError); exitErr != nil {
			stderr = string(exitErr.Stderr)
		}
		return nil, rawCmd, fmt.Errorf("command %q failed: %w\nstderr: %s", rawCmd, err, stderr)
	}
	return out, rawCmd, nil
}

// truncate returns at most n bytes of b as a string, with a suffix if cut.
func truncate(b []byte, n int) string {
	if len(b) <= n {
		return string(b)
	}
	return string(b[:n]) + "…"
}
