#!/bin/bash
set -euxo pipefail

etcd_version="${1:-v3.5.14}"; shift || true

# install the binaries.
url="https://github.com/etcd-io/etcd/releases/download/$etcd_version/etcd-$etcd_version-linux-amd64.tar.gz"
filename="$(basename "$url")"
wget -q "$url"
rm -rf etcd && mkdir etcd
tar xf "$filename" --strip-components 1 -C etcd
install etcd/etcdctl /usr/local/bin
rm -rf "$filename" etcd

# configure the user environment to access etcd.
cat >/etc/profile.d/etcdctl.sh <<'EOF'
export ETCDCTL_CACERT=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt
export ETCDCTL_CERT=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt
export ETCDCTL_KEY=/var/lib/rancher/k3s/server/tls/etcd/server-client.key
EOF
