#!/bin/bash
set -euxo pipefail

cert_manager_chart_version="${1:-1.15.1}"; shift || true

# provision cert-manager.
# NB YOU MUST INSTALL CERT-MANAGER TO THE cert-manager NAMESPACE. the CRDs have it hard-coded.
# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# NB the CRDs have to be installaled separately from the chart.
# TODO would it make sense to have a separate helm chart for installing the CRDs?
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/jetstack/cert-manager/tree/master/deploy/charts/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
# see https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers
# see https://cert-manager.io/docs/usage/ingress/
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo 'Setting the cert-manager values...'
# NB the default values are described at:
#       https://github.com/cert-manager/cert-manager/blob/v1.15.1/deploy/charts/cert-manager/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
cat >cert-manager-values.yml <<EOF
# NB YOLO the CRDs.
crds:
  enabled: true
  keep: false
EOF

echo 'Installing cert-manager...'
helm upgrade --install \
  cert-manager \
  jetstack/cert-manager \
  --namespace cert-manager \
  --version "$cert_manager_chart_version" \
  --create-namespace \
  --values cert-manager-values.yml \
  --wait

echo 'Creating the ingress ca...'
kubectl apply -f - <<'EOF'
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ingress
  namespace: cert-manager
spec:
  isCA: true
  subject:
    organizations:
      - k3s-vagrant
    organizationalUnits:
      - Kubernetes
  commonName: Kubernetes Ingress
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  duration: 8h # NB this is so low for testing purposes. default is 2160h (90 days).
  secretName: ingress-tls
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ingress
spec:
  ca:
    secretName: ingress-tls
EOF

# export the ingress ca certificate to the host.
kubectl get secret \
  --namespace cert-manager \
  --output jsonpath='{.data.ca\.crt}' \
  ingress-tls \
  | base64 --decode >/vagrant/tmp/ingress-ca-crt.pem

# trust the ingress ca.
install /vagrant/tmp/ingress-ca-crt.pem /usr/local/share/ca-certificates/ingress.crt
update-ca-certificates
