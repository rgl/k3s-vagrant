#!/bin/bash
set -euxo pipefail

# make sure we have the gitlab-runner registration token.
# NB this only works when https://github.com/rgl/gitlab-vagrant running at ../gitlab-vagrant
[ -f /vagrant/tmp/gitlab-runner-authentication-token-kubernetes-k3s.json ] || exit 0

gitlab_runner_chart_version="${1:-0.63.0}"; shift || true
gitlab_fqdn="${1:-gitlab.example.com}"; shift || true
gitlab_ip="${1:-10.10.9.99}"; shift || true
gitlab_runner_authentication_token="$(jq -r .token /vagrant/tmp/gitlab-runner-authentication-token-kubernetes-k3s.json)"

# trust the gitlab certificate.
cp /vagrant/tmp/$gitlab_fqdn-crt.pem /usr/local/share/ca-certificates/$gitlab_fqdn.crt
update-ca-certificates

# add the gitlab helm charts repository.
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# search the chart and app versions, e.g.: in this case we are using:
#     NAME                 CHART VERSION APP VERSION DESCRIPTION
#     gitlab/gitlab-runner 0.63.0        16.10.0     GitLab Runner
helm search repo gitlab/gitlab-runner --versions | head -10

# create the namespace.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: gitlab-runner
EOF

# create the secret for the trusted certificates.
kubectl create secret \
  generic \
  gitlab-runner-certs \
  --namespace gitlab-runner \
  --from-file=$gitlab_fqdn.crt=/usr/local/share/ca-certificates/$gitlab_fqdn.crt \
  --dry-run=client \
  --output yaml \
  | kubectl apply -f -

# set the configuration.
# NB the default values are described at:
#       https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.63.0/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
# see https://docs.gitlab.com/runner/executors/kubernetes/index.html
cat >gitlab-runner-values.yml <<EOF
gitlabUrl: https://$gitlab_fqdn
runnerToken: "$gitlab_runner_authentication_token"
certsSecretName: gitlab-runner-certs
rbac:
  create: true
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "ubuntu:22.04"
hostAliases:
  - ip: $gitlab_ip
    hostnames:
      - $gitlab_fqdn
EOF

# install.
# see https://docs.gitlab.com/runner/install/kubernetes.html
helm upgrade --install \
  gitlab-runner \
  gitlab/gitlab-runner \
  --version $gitlab_runner_chart_version \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yml
