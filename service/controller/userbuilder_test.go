package controller

import (
	"testing"

	"github.com/XrayR-project/XrayR/api"
)

func TestVlessFlowForNode(t *testing.T) {
	tests := []struct {
		name string
		node api.NodeInfo
		want string
	}{
		{
			name: "defaults TCP REALITY to Vision",
			node: api.NodeInfo{EnableREALITY: true, TransportProtocol: "tcp"},
			want: "xtls-rprx-vision",
		},
		{
			name: "keeps panel supplied flow",
			node: api.NodeInfo{EnableREALITY: true, TransportProtocol: "tcp", VlessFlow: "xtls-rprx-vision"},
			want: "xtls-rprx-vision",
		},
		{
			name: "does not set flow for non TCP REALITY",
			node: api.NodeInfo{EnableREALITY: true, TransportProtocol: "grpc"},
			want: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := vlessFlowForNode(&tt.node); got != tt.want {
				t.Fatalf("vlessFlowForNode() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestBuildSSUserSkipsInvalidShadowsocks2022Key(t *testing.T) {
	controller := &Controller{panelType: "NewV2board", Tag: "node"}
	userInfo := []api.UserInfo{{
		UID:    1,
		Email:  "invalid@example.com",
		Passwd: "too-short",
	}}

	users := controller.buildSSUser(&userInfo, "2022-blake3-aes-256-gcm")
	if len(users) != 0 {
		t.Fatalf("buildSSUser() returned %d users, want 0", len(users))
	}
}

func TestBuildSSPluginUserDoesNotReturnNilEntries(t *testing.T) {
	controller := &Controller{panelType: "NewV2board", Tag: "node"}
	userInfo := []api.UserInfo{
		{UID: 1, Email: "valid@example.com", Passwd: "password", Method: "aes-128-gcm"},
		{UID: 2, Email: "invalid@example.com", Passwd: "password", Method: "unsupported"},
	}

	users := controller.buildSSPluginUser(&userInfo)
	if len(users) != 1 {
		t.Fatalf("buildSSPluginUser() returned %d users, want 1", len(users))
	}
	if users[0] == nil {
		t.Fatal("buildSSPluginUser() returned a nil user")
	}
}
