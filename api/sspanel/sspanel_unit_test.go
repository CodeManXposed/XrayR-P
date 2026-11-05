package sspanel

import "testing"

func TestReadLocalRuleListMissingFile(t *testing.T) {
	rules := readLocalRuleList("/path/that/does/not/exist")
	if len(rules) != 0 {
		t.Fatalf("readLocalRuleList() returned %d rules, want 0", len(rules))
	}
}
