#!/bin/bash
set -euxo pipefail

kubernetes_dashboard_chart_version="${1:-v7.5.0}"; shift || true
kubernetes_dashboard_fqdn="kubernetes-dashboard.$(hostname --domain)"

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
app:
  ingress:
    enabled: true
    useDefaultIngressClass: true
    useDefaultAnnotations: false
    hosts:
      - $kubernetes_dashboard_fqdn
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
