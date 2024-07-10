#!/bin/bash
set -euxo pipefail

reloader_chart_version="${1:-1.0.116}"; shift || true

# add the stakater reloader repository.
# see https://github.com/stakater/reloader
# see https://artifacthub.io/packages/helm/stakater/reloader
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

echo 'Setting the reloader values...'
cat >reloader-values.yml <<EOF
reloader:
  autoReloadAll: false
EOF

echo 'Installing reloader...'
helm upgrade --install \
  reloader \
  stakater/reloader \
  --namespace kube-system \
  --version "$reloader_chart_version" \
  --values reloader-values.yml \
  --wait
