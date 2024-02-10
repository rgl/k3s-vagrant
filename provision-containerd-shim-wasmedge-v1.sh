#!/bin/bash
set -euxo pipefail

# see https://github.com/containerd/runwasi
# renovate: datasource=github-releases depName=containerd/runwasi extractVersion=containerd-shim-wasmedge/v(?<version>.+)
CONTAINERD_RUNWASI_VERSION='0.3.0'

# bail when already installed.
if [ -x /usr/local/bin/containerd-shim-wasmedge-v1 ]; then
    # e.g. Version: 0.3.0
    actual_version="$(/usr/local/bin/containerd-shim-wasmedge-v1 -v | perl -ne '/^\s*Version: (.+)/ && print $1')"
    if [ "$actual_version" == "$CONTAINERD_RUNWASI_VERSION" ]; then
        echo 'ANSIBLE CHANGED NO'
        exit 0
    fi
fi

# download and install.
containerd_runwasi_url="https://github.com/containerd/runwasi/releases/download/containerd-shim-wasmedge%2Fv${CONTAINERD_RUNWASI_VERSION}/containerd-shim-wasmedge-x86_64.tar.gz"
t="$(mktemp -q -d --suffix=.containerd-runwasi)"
wget -qO- "$containerd_runwasi_url" | tar xzf - -C "$t"
install -m 755 "$t/containerd-shim-wasmedge-v1" /usr/local/bin/
rm -rf "$t"
