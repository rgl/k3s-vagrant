#!/bin/bash
set -euxo pipefail

kubernetes_dashboard_chart_version="${1:-v7.5.0}"; shift || true
kubernetes_dashboard_fqdn="kubernetes-dashboard.$(hostname --domain)"

# create the kubernetes-dashboard tls secret.
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/
kubectl create namespace kubernetes-dashboard
kubectl apply -n kubernetes-dashboard -f - <<EOF
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kubernetes-dashboard
spec:
  subject:
    organizations:
      - k3s-vagrant
    organizationalUnits:
      - Kubernetes
  commonName: Kubernetes Dashboard
  dnsNames:
    - $kubernetes_dashboard_fqdn
  duration: 1h # NB this is so low for testing purposes.
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  secretName: kubernetes-dashboard-tls
  issuerRef:
    kind: ClusterIssuer
    name: ingress
EOF
kubectl wait --timeout=5m --for=condition=Ready --namespace kubernetes-dashboard certificate/kubernetes-dashboard

# create the ingress.
# see https://kubernetes.io/docs/concepts/services-networking/ingress/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#ingress-v1-networking-k8s-io
kubectl apply -n kubernetes-dashboard -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
spec:
  rules:
    - host: $kubernetes_dashboard_fqdn
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-kong-proxy
                port:
                  name: kong-proxy
  tls:
    - secretName: kubernetes-dashboard-tls
EOF

# add the kubernetes-dashboard helm charts repository.
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update

# search the chart and app versions, e.g., in this case we are using:
# NAME                                     	 CHART VERSION  APP VERSION  DESCRIPTION
# kubernetes-dashboard/kubernetes-dashboard          7.5.0               General-purpose web UI for Kubernetes clusters
helm search repo kubernetes-dashboard/kubernetes-dashboard --versions | head -10

# set the configuration.
# see https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard
# see https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
# see https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/Chart.yaml
cat >kubernetes-dashboard-values.yml <<EOF
kong:
  proxy:
    http:
      enabled: true
api:
  scaling:
    replicas: 1
EOF

# install.
# see https://github.com/kubernetes/dashboard
# see https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
helm upgrade --install \
  kubernetes-dashboard \
  kubernetes-dashboard/kubernetes-dashboard \
  --version "$kubernetes_dashboard_chart_version" \
  --create-namespace \
  --namespace kubernetes-dashboard \
  --values kubernetes-dashboard-values.yml \
  --wait

# create the admin user for use in the kubernetes-dashboard.
# see https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
# see https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md
# see https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
kubectl apply -n kubernetes-dashboard -f - <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: admin
  annotations:
    kubernetes.io/service-account.name: admin
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: kubernetes-dashboard
EOF
# save the admin token.
kubectl -n kubernetes-dashboard get secret admin -o json \
  | jq -r .data.token \
  | base64 --decode \
  >/vagrant/tmp/admin-token.txt
