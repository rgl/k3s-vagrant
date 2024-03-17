#!/bin/bash
set -euxo pipefail

crossplane_chart_version="${1:-1.15.1}"; shift || true
crossplane_provider_aws_s3_version="${1:-1.2.0}"; shift || true

# add the crossplane helm charts repository.
helm repo add crossplane https://charts.crossplane.io/stable
helm repo update

# search the chart and app versions, e.g.: in this case we are using:
#   NAME                   CHART VERSION  APP VERSION  DESCRIPTION
#   crossplane/crossplane  1.15.1         1.15.1       Crossplane is an open source Kubernetes add-on ...
helm search repo crossplane/crossplane --versions | head -10

# set the configuration.
# NB the default values are described at:
#       https://github.com/crossplane/crossplane/tree/master/cluster/charts/crossplane/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
# see https://docs.crossplane.io/v1.15/software/install/#customize-the-crossplane-helm-chart
cat >crossplane-values.yml <<EOF
# empty.
EOF

# install.
helm upgrade --install \
  crossplane \
  crossplane/crossplane \
  --version "$crossplane_chart_version" \
  --create-namespace \
  --namespace crossplane-system \
  --values crossplane-values.yml \
  --wait

# install the aws providers.
# NB this is cluster-wide.
# NB Provider is cluster scoped.
#    see kubectl get crd providers.pkg.crossplane.io -o yaml
# see https://docs.crossplane.io/v1.15/api/
# see https://marketplace.upbound.io/providers/upbound/provider-aws-s3/v1.2.0
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v$crossplane_provider_aws_s3_version
EOF
kubectl wait \
  provider.pkg.crossplane.io/provider-aws-s3 \
  --for condition=healthy \
  --timeout 5m

# configure the aws credentials.
if [ -r /vagrant/tmp/aws-credentials.txt ]; then
  kubectl create secret generic aws-credentials \
    --namespace crossplane-system \
    --from-file credentials=/vagrant/tmp/aws-credentials.txt
fi
# NB ProviderConfig is cluster scoped.
#    see kubectl get crd providerconfigs.aws.upbound.io -o yaml
kubectl apply -f - <<'EOF'
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
EOF
