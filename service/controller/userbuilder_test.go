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
