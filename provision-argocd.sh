#!/bin/bash
set -euxo pipefail

argocd_cli_version="${1:-2.12.0}"; shift || true
argocd_chart_version="${1:-7.4.2}"; shift || true
argocd_fqdn="argocd.$(hostname --domain)"

# create the argocd-server tls secret.
# NB argocd-server will automatically reload this secret.
# NB alternatively we could set the server.certificate.enabled helm value. but
#    that does not allow us to fully customize the certificate (e.g. subject).
# see https://github.com/argoproj/argo-helm/blob/argo-cd-7.4.2/charts/argo-cd/templates/argocd-server/certificate.yaml
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/
kubectl create namespace argocd
kubectl apply -n argocd -f - <<EOF
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-server
spec:
  subject:
    organizations:
      - k3s-vagrant
    organizationalUnits:
      - Kubernetes
  commonName: Argo CD Server
  dnsNames:
    - $argocd_fqdn
  duration: 1h # NB this is so low for testing purposes.
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  secretName: argocd-server-tls
  issuerRef:
    kind: ClusterIssuer
    name: ingress
EOF
kubectl wait --timeout=5m --for=condition=Ready --namespace argocd certificate/argocd-server

# create the argocd-repo-server tls secret.
# NB argocd-repo-server will NOT automatically reload this secret. instead, the
#    argocd-repo-server is configured to be automatically restarted by the
#    reloader controller.
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/
kubectl apply -n argocd -f - <<EOF
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-repo-server
spec:
  subject:
    organizations:
      - k3s-vagrant
    organizationalUnits:
      - Kubernetes
  commonName: Argo CD Repo Server
  dnsNames:
    - argocd-repo-server
    - argocd-repo-server.argocd.svc
  duration: 1h # NB this is so low for testing purposes.
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  secretName: argocd-repo-server-tls
  issuerRef:
    kind: ClusterIssuer
    name: ingress
EOF
kubectl wait --timeout=5m --for=condition=Ready --namespace argocd certificate/argocd-repo-server

# create the argocd-dex-server tls secret.
# NB argocd-dex-server will NOT automatically reload this secret. instead, the
#    argocd-dex-server is configured to be automatically restarted by the
#    reloader controller.
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/
kubectl apply -n argocd -f - <<EOF
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
 name: argocd-dex-server
spec:
 subject:
   organizations:
     - k3s-vagrant
   organizationalUnits:
     - Kubernetes
 commonName: Argo CD Dex Server
 dnsNames:
   - argocd-dex-server
   - argocd-dex-server.argocd.svc
 duration: 1h # NB this is so low for testing purposes.
 privateKey:
   algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
   size: 256
 secretName: argocd-dex-server-tls
 issuerRef:
   kind: ClusterIssuer
   name: ingress
EOF
kubectl wait --timeout=5m --for=condition=Ready --namespace argocd certificate/argocd-dex-server

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
#     argo/argo-cd    7.4.2         v2.12.0     A Helm chart for Argo CD, a declarative, GitOps...
helm search repo argo/argo-cd --versions | head -10

# set the configuration.
# NB the default values are described at:
#       https://github.com/argoproj/argo-helm/blob/argo-cd-7.4.2/charts/argo-cd/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
cat >argocd-values.yml <<EOF
global:
  domain: $argocd_fqdn
server:
  ingress:
    enabled: true
    tls: true
  extraArgs:
    - --repo-server-strict-tls
    - --dex-server-strict-tls
controller:
  extraArgs:
    - --repo-server-strict-tls
repoServer:
  deploymentAnnotations:
    secret.reloader.stakater.com/reload: argocd-repo-server-tls
dex:
  deploymentAnnotations:
    secret.reloader.stakater.com/reload: argocd-dex-server-tls
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

# verify the certificates.
# NB to further troubleshoot, add the -debug -tlsextdebug cli arguments.
endpoints=(
  'argocd.example.test:443'
  'argocd-repo-server.argocd.svc:8081'
  # NB dex verification is commented because we have not configured dex, as
  #    such, there is not endpoint listening, so we cannot verify the
  #    certificate.
  #'argocd-dex-server.argocd.svc:5556'
)
for endpoint in "${endpoints[@]}"; do
  h="${endpoint%:*}"
  kubectl -n argocd exec --stdin deployment/argocd-server -- bash -eux <<EOF
# dump certificate.
openssl s_client \
  -connect "$endpoint" \
  -servername "$h" \
  </dev/null \
  2>/dev/null \
  | openssl x509 -noout -text
# verify certificate.
openssl s_client \
  -connect "$endpoint" \
  -servername "$h" \
  -showcerts \
  -verify 100 \
  -verify_return_error \
  -CAfile <(echo "$(cat /vagrant/tmp/ingress-ca-crt.pem)")
EOF
done

# configure argocd.
export ARGOCD_SERVER="$argocd_fqdn"
export ARGOCD_AUTH_USERNAME="admin"
export ARGOCD_AUTH_PASSWORD="$(cat /vagrant/tmp/argocd-admin-password.txt)"
export CHECKPOINT_DISABLE=1
export TF_LOG=DEBUG # TF_LOG can be one of: ERROR, WARN, INFO, DEBUG, TRACE.
export TF_LOG_PATH=terraform.log
pushd /vagrant/argocd
rm -f terraform.tfstate* terraform*.log
terraform init
terraform apply -auto-approve \
  | tee terraform-apply.log
popd
