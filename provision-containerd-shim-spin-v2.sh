#!/bin/bash
set -euxo pipefail

# see https://github.com/spinkube/containerd-shim-spin
# renovate: datasource=github-releases depName=spinkube/containerd-shim-spin
CONTAINERD_SHIM_SPIN_VERSION='0.15.0'

# bail when already installed.
if [ -x /usr/local/bin/containerd-shim-spin-v2 ]; then
    # e.g. Version: 0.15.0
    actual_version="$(/usr/local/bin/containerd-shim-spin-v2 -v | perl -ne '/^\s*Version: (.+)/ && print $1')"
    if [ "$actual_version" == "$CONTAINERD_SHIM_SPIN_VERSION" ]; then
        echo 'ANSIBLE CHANGED NO'
        exit 0
    fi
fi

# download and install.
containerd_shim_spin_url="https://github.com/spinkube/containerd-shim-spin/releases/download/v${CONTAINERD_SHIM_SPIN_VERSION}/containerd-shim-spin-v2-linux-x86_64.tar.gz"
t="$(mktemp -q -d --suffix=.containerd-shim-spin)"
wget -qO- "$containerd_shim_spin_url" | tar xzf - -C "$t"
install -m 755 "$t/containerd-shim-spin-v2" /usr/local/bin/
rm -rf "$t"
