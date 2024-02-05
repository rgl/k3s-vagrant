#!/bin/bash
set -euxo pipefail

# see https://github.com/deislabs/containerd-wasm-shims
# renovate: datasource=github-releases depName=deislabs/containerd-wasm-shims
CONTAINERD_WASM_SHIMS_VERSION='0.10.0'

# bail when already installed.
if [ -x /usr/local/bin/containerd-shim-spin-v2 ]; then
    # e.g. Version: 0.3.0
    actual_version="$(/usr/local/bin/containerd-shim-spin-v2 -v | perl -ne '/^\s*Version: (.+)/ && print $1')"
    if [ "$actual_version" == "$CONTAINERD_WASM_SHIMS_VERSION" ]; then
        echo 'ANSIBLE CHANGED NO'
        exit 0
    fi
fi

# download and install.
containerd_wasm_shims_url="https://github.com/deislabs/containerd-wasm-shims/releases/download/v${CONTAINERD_WASM_SHIMS_VERSION}/containerd-wasm-shims-v2-spin-linux-x86_64.tar.gz"
t="$(mktemp -q -d --suffix=.containerd-wasm-shims)"
wget -qO- "$containerd_wasm_shims_url" | tar xzf - -C "$t"
install -m 755 "$t/containerd-shim-spin-v2" /usr/local/bin/
rm -rf "$t"

# configure k3s containerd.
# see https://docs.k3s.io/advanced#configuring-containerd
# see https://github.com/deislabs/containerd-wasm-shims
# see https://github.com/deislabs/containerd-wasm-shims/blob/main/containerd-shim-spin/src/main.rs
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
