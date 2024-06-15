#!/bin/bash
set -euxo pipefail

argocd_cli_version="${1:-2.11.3}"; shift || true
argocd_chart_version="${1:-7.1.3}"; shift || true
argocd_fqdn="argocd.$(hostname --domain)"

# install the argocd cli.
argocd_url="https://github.com/argoproj/argo-cd/releases/download/v$argocd_cli_version/argocd-linux-amd64"
t="$(mktemp -q -d --suffix=.argocd)"
wget -qO "$t/argocd" "$argocd_url"
install -m 755 "$t/argocd" /usr/local/bin/
rm -rf "$t"

# add the argo helm charts repository.
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# search the chart and app versions, e.g.: in this case we are using:
#     NAME            CHART VERSION APP VERSION DESCRIPTION
#     argo/argo-cd    7.1.3         v2.11.3     A Helm chart for Argo CD, a declarative, GitOps...
helm search repo argo/argo-cd --versions | head -10

# set the configuration.
# NB the default values are described at:
#       https://github.com/argoproj/argo-helm/blob/argo-cd-7.1.3/charts/argo-cd/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
cat >argocd-values.yml <<EOF
global:
  domain: $argocd_fqdn
server:
  ingress:
    enabled: true
configs:
  params:
    server.insecure: true
EOF

# install.
helm upgrade --install \
  argocd \
  argo/argo-cd \
  --version "$argocd_chart_version" \
  --create-namespace \
  --namespace argocd \
  --values argocd-values.yml \
  --wait

# save the admin password.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \
  | base64 --decode \
  > /vagrant/tmp/argocd-admin-password.txt
