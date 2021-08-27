#!/bin/bash
set -euxo pipefail

# make sure we have the gitlab-runner registration token.
# NB this only works when https://github.com/rgl/gitlab-vagrant running at ../gitlab-vagrant
[ -f /vagrant/tmp/gitlab-runners-registration-token.txt ] || exit 0

gitlab_runner_chart_version="${1:-0.32.0}"; shift || true
gitlab_fqdn="${1:-gitlab.example.com}"; shift || true
gitlab_ip="${1:-10.10.9.99}"; shift || true
gitlab_runner_registration_token="$(cat /vagrant/tmp/gitlab-runners-registration-token.txt)"

# trust the gitlab certificate.
cp /vagrant/tmp/$gitlab_fqdn-crt.pem /usr/local/share/ca-certificates/$gitlab_fqdn.crt
update-ca-certificates

# add the gitlab helm charts repository.
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# search the chart and app versions, e.g.: in this case we are using:
#     NAME                 CHART VERSION APP VERSION DESCRIPTION
#     gitlab/gitlab-runner 0.32.0        14.1.0      GitLab Runner
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
#       https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/v0.32.0/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
cat >gitlab-runner-values.yml <<EOF
gitlabUrl: https://$gitlab_fqdn
runnerRegistrationToken: "$gitlab_runner_registration_token"
certsSecretName: gitlab-runner-certs
rbac:
  create: true
runners:
  image: ubuntu:20.04
  tags: "k8s,k3s"
  locked: false
EOF

# install.
# see https://docs.gitlab.com/runner/install/kubernetes.html
helm upgrade --install \
  gitlab-runner \
  gitlab/gitlab-runner \
  --version $gitlab_runner_chart_version \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yml
