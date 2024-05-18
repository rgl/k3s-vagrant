#!/bin/bash
set -euxo pipefail

# NB as-of https://github.com/k3s-io/k3s/releases/tag/v1.29.3+k3s1 this
#    configuration is no longer required. its left here for reference.
# see https://github.com/k3s-io/k3s/pull/9519
exit 0

# configure k3s containerd.
# see https://docs.k3s.io/advanced#configuring-containerd
# see https://github.com/spinkube/containerd-shim-spin
# see https://github.com/spinkube/containerd-shim-spin/blob/main/containerd-shim-spin/src/main.rs
# see https://github.com/containerd/runwasi
# see https://github.com/containerd/runwasi/blob/main/crates/containerd-shim-wasmtime/src/main.rs
# see https://github.com/containerd/containerd/blob/main/runtime/v2/README.md#configuring-runtimes
# see https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md
# see containerd config default
# see containerd config dump
# NB we do not need to create a kubernetes RuntimeClass because k3s already
#    configures it at:
#       /var/lib/rancher/k3s/server/manifests/runtimes.yaml
install -d /var/lib/rancher/k3s/agent/etc/containerd
cat >/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl <<'EOF'
{{ template "base" . }}

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.spin]
  runtime_type = "io.containerd.spin.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.spin.options]
  BinaryName = "/usr/local/bin/containerd-shim-spin-v2"
EOF
