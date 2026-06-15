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
func CollectSessions(cfg Config) ([]models.Session, string, error) {
	args := buildArgs(cfg, "session")
	out, rawCmd, err := run(cfg.Binary, args)
	if err != nil {
		return nil, rawCmd, fmt.Errorf("pola session: %w", err)
	}

	// The real pola binary wraps output in {"command":..., "output":[...]}
	// but when the output is just the array directly (e.g. during testing)
	// we handle both.
	var wrapped models.SessionOutput
	if err := json.Unmarshal(out, &wrapped); err == nil && wrapped.Output != nil {
		return wrapped.Output, rawCmd, nil
	}

	var direct []models.Session
	if err := json.Unmarshal(out, &direct); err != nil {
		return nil, rawCmd, fmt.Errorf("parse session JSON: %w", err)
	}
	return direct, rawCmd, nil
}

// CollectTED runs `pola ted -j` and returns parsed results.
func CollectTED(cfg Config) ([]models.TEDNode, string, error) {
	args := buildArgs(cfg, "ted")
	out, rawCmd, err := run(cfg.Binary, args)
	if err != nil {
		return nil, rawCmd, fmt.Errorf("pola ted: %w", err)
	}

	var wrapped models.TEDOutput
	if err := json.Unmarshal(out, &wrapped); err != nil {
		return nil, rawCmd, fmt.Errorf("parse TED JSON: %w", err)
	}
	return wrapped.Output.Nodes, rawCmd, nil
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
