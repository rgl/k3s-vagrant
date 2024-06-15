#!/bin/bash
set -euo pipefail

metallb_chart_version="${1:-6.3.3}"; shift || true
lb_ip_range="${1:-10.11.0.50-10.11.0.250}"; shift || true

# add the bitnami helm charts repository.
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# install.
# see https://artifacthub.io/packages/helm/bitnami/metallb
# see https://metallb.universe.tf/configuration/k3s/
# see https://metallb.universe.tf/configuration/#layer-2-configuration
# see https://metallb.universe.tf/community/#code-organization
# see https://github.com/bitnami/charts/tree/master/bitnami/metallb
# see https://kind.sigs.k8s.io/docs/user/loadbalancer/
cat >metallb-values.yml <<EOF
speaker:
  secretValue: abracadabra # TODO use a proper secret.
controller:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
EOF
helm upgrade --install \
  metallb \
  bitnami/metallb \
  --version $metallb_chart_version \
  --namespace metallb-system \
  --create-namespace \
  --values metallb-values.yml \
  --wait

# configure.
# NB we have to retry until the metallb-webhook-service endpoint is
#    available. while its starting, it will fail with:
#       Internal error occurred: failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io": failed to call webhook: Post
#       "https://metallb-webhook-service.metallb-system.svc:443/validate-metallb-io-v1beta1-ipaddresspool?timeout=10s": dial tcp
#       10.96.9.119:443: connect: connection refused
#    see https://github.com/metallb/metallb/issues/1597
while ! kubectl -n metallb-system apply -f - <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
spec:
  addresses:
    - $lb_ip_range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
EOF
do sleep 5; done
