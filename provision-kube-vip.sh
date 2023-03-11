#!/bin/bash
set -euxo pipefail

kube_vip_version="${1:-v0.5.11}"; shift || true
vip="${1:-10.11.0.100}"; shift || true
kube_vip_rbac_url="https://raw.githubusercontent.com/kube-vip/kube-vip/$kube_vip_version/docs/manifests/rbac.yaml"
kube_vip_image="ghcr.io/kube-vip/kube-vip:$kube_vip_version"
fqdn="$(hostname --fqdn)"
k3s_fqdn="s.$(hostname --domain)"
k3s_url="https://$k3s_fqdn:6443"

# install kube-vip.
# NB this creates a HA VIP (L2 IPVS) for the k8s control-plane k3s/api-server.
# see https://kube-vip.io/docs/usage/k3s/
# see https://kube-vip.io/docs/installation/daemonset/
# see https://kube-vip.io/docs/about/architecture/
ctr image pull "$kube_vip_image"
(
  wget -qO- "$kube_vip_rbac_url"
  echo ---
  ctr run --rm --net-host "$kube_vip_image" vip \
    /kube-vip \
    manifest \
    daemonset \
    --arp \
    --interface eth1 \
    --address "$vip" \
    --inCluster \
    --taint \
    --controlplane \
    --enableLoadBalancer \
    --leaderElection
) | kubectl apply -f -

# wait until $k3s_url is available.
while ! wget \
  --quiet \
  --spider \
  --ca-certificate=/var/lib/rancher/k3s/server/tls/server-ca.crt \
  --certificate=/var/lib/rancher/k3s/server/tls/client-admin.crt \
  --private-key=/var/lib/rancher/k3s/server/tls/client-admin.key \
  "$k3s_url"; do sleep 5; done
