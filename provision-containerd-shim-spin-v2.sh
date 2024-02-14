#!/bin/bash
set -euxo pipefail

# see https://github.com/deislabs/containerd-wasm-shims
# renovate: datasource=github-releases depName=deislabs/containerd-wasm-shims
CONTAINERD_WASM_SHIMS_VERSION='0.11.0'

# bail when already installed.
if [ -x /usr/local/bin/containerd-shim-spin-v2 ]; then
    # e.g. Version: 0.11.0
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
