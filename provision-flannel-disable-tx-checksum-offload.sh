#!/bin/bash
set -euo pipefail

# it seems there's a bug in the kernel that prevents the vxlan overlay
# network from working with default settings. for this to work we need
# to disable checksum offloading in the flannel interface or we need
# to a an iptables rule. the former is simpler to implement across
# reboots.
# see https://github.com/k3s-io/k3s/issues/3863
# see https://github.com/flannel-io/flannel/issues/1279
# see https://github.com/kubernetes/kubernetes/pull/92035
# see https://github.com/hakman/kops/blob/3f8632322fce695a30956104ca349789e1a62c04/nodeup/pkg/model/network.go#L101-L123
# TODO re-evalute the need for this workaround.

while ! ip link show flannel.1 >/dev/null 2>&1; do sleep 1; done

before="$(ethtool --show-offload flannel.1)"

cat >/etc/systemd/system/flannel-disable-tx-checksum-offload.service <<'EOF'
[Unit]
Description=Disable TX checksum offload on flannel.1
After=sys-devices-virtual-net-flannel.1.device

[Service]
Type=oneshot
ExecStart=/sbin/ethtool --offload flannel.1 tx-checksum-ip-generic off

[Install]
WantedBy=sys-devices-virtual-net-flannel.1.device
EOF
systemctl enable flannel-disable-tx-checksum-offload
systemctl start flannel-disable-tx-checksum-offload

after="$(ethtool --show-offload flannel.1)"

diff -u <(echo "$before") <(echo "$after") || true
