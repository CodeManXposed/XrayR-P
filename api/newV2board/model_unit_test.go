package newV2board

import (
	"encoding/json"
	"testing"
)

func TestRealityXVerIsDecodedAndApplied(t *testing.T) {
	data := []byte(`{
		"server_port": 443,
		"network": "tcp",
		"tls": 2,
		"tls_settings": {
			"server_port": "443",
			"dest": "example.com",
			"xver": 2,
			"server_name": "example.com",
			"private_key": "private-key",
			"short_id": "01234567"
		}
	}`)

	var config serverConfig
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	client := &APIClient{NodeID: 1, NodeType: "V2ray", EnableVless: true}
	nodeInfo, err := client.parseV2rayNodeResponse(&config)
	if err != nil {
		t.Fatalf("parseV2rayNodeResponse() error = %v", err)
	}
	if nodeInfo.REALITYConfig == nil {
		t.Fatal("parseV2rayNodeResponse() returned no REALITY config")
	}
	if got := nodeInfo.REALITYConfig.ProxyProtocolVer; got != 2 {
		t.Fatalf("ProxyProtocolVer = %d, want 2", got)
	}
}

func TestReadLocalRuleListMissingFile(t *testing.T) {
	rules := readLocalRuleList("/path/that/does/not/exist")
	if len(rules) != 0 {
		t.Fatalf("readLocalRuleList() returned %d rules, want 0", len(rules))
	}
}
