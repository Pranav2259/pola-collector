package models

// ─── Session ────────────────────────────────────────────────────────────────

type SessionOutput struct {
	Command string    `json:"command"`
	Output  []Session `json:"output"`
}

type Session struct {
	Addr     string   `json:"Addr"`
	State    string   `json:"State"`
	Caps     []string `json:"Caps"`
	IsSynced bool     `json:"IsSynced"`
}

// ─── TED ────────────────────────────────────────────────────────────────────

// TEDDirect is what the real `pola ted -j` binary emits: {"ted":[...]}
type TEDDirect struct {
	Nodes []TEDNode `json:"ted"`
}

// TEDOutput is the wrapped format from the sample JSON files:
// {"command":"...","output":{"ted":[...]}}
// Kept for test/replay compatibility.
type TEDOutput struct {
	Command string    `json:"command"`
	Output  TEDDirect `json:"output"`
}

type TEDNode struct {
	ASN        int       `json:"asn"`
	Hostname   string    `json:"hostname"`
	ISISAreaID string    `json:"isisAreaID"`
	RouterID   string    `json:"routerID"`
	SRGBBegin  int       `json:"srgbBegin"`
	SRGBEnd    int       `json:"srgbEnd"`
	Links      []Link    `json:"links"`
	Prefixes   []Prefix  `json:"prefixes"`
}

type Link struct {
	AdjSID     int      `json:"adjSid"`
	LocalIP    string   `json:"localIP"`
	RemoteIP   string   `json:"remoteIP"`
	RemoteNode string   `json:"remoteNode"`
	Metrics    []Metric `json:"metrics"`
}

type Metric struct {
	Type  string `json:"type"`
	Value int    `json:"value"`
}

type Prefix struct {
	Prefix   string `json:"prefix"`
	SIDIndex *int   `json:"sidIndex,omitempty"`
}
