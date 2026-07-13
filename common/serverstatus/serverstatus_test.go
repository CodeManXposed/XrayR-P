package serverstatus

import "testing"

func TestGetSystemInfo(t *testing.T) {
	_, _, _, _, err := GetSystemInfo()
	if err != nil {
		t.Fatalf("GetSystemInfo() error = %v", err)
	}
}
