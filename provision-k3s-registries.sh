#!/bin/bash
set -euxo pipefail

registry_mirror_url="http://registry.$(hostname --domain):5001"
registries='
docker.io
registry.k8s.io
ghcr.io
quay.io
registry.gitlab.com
'

# configure the registries.
# NB this rewrite configuration ends-up in the containerd configuration, but,
#    only works because k3s is using a custom fork of containerd.
# see https://docs.k3s.io/installation/private-registry#rewrites
# see /var/lib/rancher/k3s/agent/etc/containerd/config.toml
# see https://github.com/k3s-io/k3s/blob/v1.28.5%2Bk3s1/pkg/agent/templates/templates_linux.go
# see https://github.com/k3s-io/k3s/pull/3064
# see https://github.com/rancher/rke2/issues/741
# see https://github.com/containerd/containerd/pull/5171
install -d /etc/rancher/k3s
cat >/etc/rancher/k3s/registries.yaml <<EOF
mirrors:
EOF
for d in $registries; do
  cat >>/etc/rancher/k3s/registries.yaml <<EOF
  $d:
    endpoint:
      - $registry_mirror_url
    rewrite:
      "(.*)": "mirror/$d/\$1"
EOF
done
