#!/bin/bash
set -euxo pipefail

k3s_command="$1"; shift
k3s_channel="${1:-latest}"; shift
k3s_version="${1:-v1.29.2+k3s1}"; shift
k3s_token="$1"; shift
flannel_backend="$1"; shift
ip_address="$1"; shift
krew_version="${1:-v0.4.4}"; shift || true # NB see https://github.com/kubernetes-sigs/krew
taint="${1:-1}"; shift || true
fqdn="$(hostname --fqdn)"
k3s_fqdn="s.$(hostname --domain)"
k3s_url="https://$k3s_fqdn:6443"

# configure the motd.
# NB this was generated at http://patorjk.com/software/taag/#p=display&f=Big&t=k3s%0Aserver.
#    it could also be generated with figlet.org.
cat >/etc/motd <<'EOF'

  _    ____
 | |  |___ \
 | | __ __) |___
 | |/ /|__ </ __|
 |   < ___) \__ \
 |_|\_\____/|___/   _____ _ __
 / __|/ _ \ '__\ \ / / _ \ '__|
 \__ \  __/ |   \ V /  __/ |
 |___/\___|_|    \_/ \___|_|

EOF

# extra k3s server arguments.
k3s_extra_args=''

# init or join the cluster.
if [ "$k3s_command" == 'cluster-init' ]; then
  k3s_extra_args="$k3s_extra_args --cluster-init"
else
  k3s_extra_args="$k3s_extra_args --server $k3s_url"
fi

# taint.
if [ "$taint" == '1' ]; then
  k3s_extra_args="$k3s_extra_args --node-taint CriticalAddonsOnly=true:NoExecute"
fi

# install k3s.
# see server arguments at e.g. https://github.com/k3s-io/k3s/blob/v1.29.2+k3s1/pkg/cli/cmds/server.go#L566-L574
# or run k3s server --help
# see https://docs.k3s.io/installation/configuration
# see https://docs.k3s.io/reference/server-config
curl -sfL https://raw.githubusercontent.com/k3s-io/k3s/$k3s_version/install.sh \
    | \
        INSTALL_K3S_CHANNEL="$k3s_channel" \
        INSTALL_K3S_VERSION="$k3s_version" \
        K3S_TOKEN="$k3s_token" \
        sh -s -- \
            server \
            --node-ip "$ip_address" \
            --cluster-cidr '10.12.0.0/16' \
            --service-cidr '10.13.0.0/16' \
            --cluster-dns '10.13.0.10' \
            --cluster-domain 'cluster.local' \
            --flannel-iface 'eth1' \
            --flannel-backend "$flannel_backend" \
            --tls-san "$k3s_fqdn" \
            --disable servicelb \
            $k3s_extra_args

# see the systemd unit.
systemctl cat k3s

# check whether this system has the k3s requirements.
k3s check-config

# wait for this node to be Ready.
# e.g. s1     Ready    control-plane,master   3m    v1.29.2+k3s1
$SHELL -c 'node_name=$(hostname); echo "waiting for node $node_name to be ready..."; while [ -z "$(kubectl get nodes $node_name | grep -E "$node_name\s+Ready\s+")" ]; do sleep 3; done; echo "node ready!"'

# wait for the kube-dns pod to be Running.
# e.g. coredns-fb8b8dccf-rh4fg   1/1     Running   0          33m
$SHELL -c 'while [ -z "$(kubectl get pods --selector k8s-app=kube-dns --namespace kube-system | grep -E "\s+Running\s+")" ]; do sleep 3; done'

# install traefik as the k8s ingress controller.
# NB this is changing the /var/lib/rancher/k3s/server/manifests/traefik.yaml file
#    which will eventually be picked up by k3s, which will apply it using
#    something equivalent to:
#       kubectl -n kube-system apply -f /var/lib/rancher/k3s/server/manifests/traefik.yaml
# see https://doc.traefik.io/traefik/v2.9/operations/api/
# see https://github.com/k3s-io/k3s/issues/350#issuecomment-511218588
# see https://github.com/k3s-io/k3s/blob/v1.29.2+k3s1/manifests/traefik.yaml
# see https://github.com/traefik/traefik-helm-chart/blob/v25.0.2/traefik/values.yaml
echo 'configuring traefik...'
apt-get install -y python3-yaml
python3 - <<'EOF'
import difflib
import io
import sys
import yaml

# configure the yaml library to write multiline strings using the block scalar
# style syntax.
# NB this uses a modified version of https://github.com/yaml/pyyaml/issues/240#issuecomment-1096224358:
#      * uses the `in` operator.
def str_presenter(dumper, data):
    """configures yaml for dumping multiline strings
    Ref: https://stackoverflow.com/questions/8640959/how-can-i-control-what-scalar-form-pyyaml-uses-for-my-data"""
    if '\n' in data:
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)
yaml.add_representer(str, str_presenter)
yaml.representer.SafeRepresenter.add_representer(str, str_presenter) # to use with safe_dum

config_path = '/var/lib/rancher/k3s/server/manifests/traefik.yaml'
config_orig = open(config_path, 'r', encoding='utf-8').read()

documents = list(yaml.load_all(config_orig, Loader=yaml.FullLoader))
d = documents[1]
values = yaml.load(d['spec']['valuesContent'], Loader=yaml.FullLoader)

# configure logging.
# NB you can see the logs with:
#       kubectl -n kube-system logs -f -l app.kubernetes.io/name=traefik
values['logs'] = {
    'general': {
        'level': 'WARN',
    },
    'access': {
        'enabled': True,
    },
}

# configure traefik to skip certificate validation.
# NB this is needed to expose the k8s dashboard as an ingress at
#    https://kubernetes-dashboard.example.test.
# NB without this, traefik returns "internal server error".
# TODO see how to set the CAs in traefik.
# NB this should never be done at production.
values['additionalArguments'] = [
    '--serverstransport.insecureskipverify=true'
]

# save values back.
config = io.StringIO()
yaml.dump(values, config, default_flow_style=False)
d['spec']['valuesContent'] = config.getvalue()

# show the differences and save the modified yaml file.
config = io.StringIO()
yaml.dump_all(documents, config, default_flow_style=False)
config = config.getvalue()
sys.stdout.writelines(difflib.unified_diff(config_orig.splitlines(1), config.splitlines(1)))
open(config_path, 'w', encoding='utf-8').write(config)
EOF

# create the traefik ingress to access the traefik api/dashboard endpoints.
# NB you cannot use kubectl apply here because the traefik CRDs are created
#    from a non control-plane node. that's why this uses a local manifest
#    file.
# NB you must add any of the cluster node IP addresses to your computer hosts file, e.g.:
#       10.11.10.101 traefik.example.test
#    and access it as:
#       https://traefik.example.test/dashboard/
#       https://traefik.example.test/api/version
#       https://traefik.example.test/api/overview
#       https://traefik.example.test/api/http/routers
#       https://traefik.example.test/api/http/services
# NB you can see the traefik configuration with:
#       kubectl --namespace kube-system get configmap/chart-values-traefik -o yaml
#       kubectl --namespace kube-system get pods -l app.kubernetes.io/name=traefik -o yaml
#       kubectl --namespace kube-system logs -l app.kubernetes.io/name=traefik
# see https://doc.traefik.io/traefik/operations/api/#endpoints
# see kubectl get -n kube-system service traefik -o yaml
# see https://github.com/traefik/traefik-helm-chart/tree/v25.0.0#exposing-the-traefik-dashboard
cat >/var/lib/rancher/k3s/server/manifests/traefik-local.yaml <<'EOF'
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.example.test`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
EOF

# install the krew kubectl package manager.
echo "installing the krew $krew_version kubectl package manager..."
apt-get install -y --no-install-recommends git-core
wget -qO- "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew-linux_amd64.tar.gz" | tar xzf - ./krew-linux_amd64
wget -q "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew.yaml"
./krew-linux_amd64 install --manifest=krew.yaml
rm krew-linux_amd64
cat >/etc/profile.d/krew.sh <<'EOF'
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
EOF
source /etc/profile.d/krew.sh
kubectl krew version

# install the bash completion scripts.
crictl completion bash >/usr/share/bash-completion/completions/crictl
kubectl completion bash >/usr/share/bash-completion/completions/kubectl

# symlink the default kubeconfig path so local tools like k9s can easily
# find it without exporting the KUBECONFIG environment variable.
ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config

# save kubeconfig in the host.
# NB the default users are generated at https://github.com/k3s-io/k3s/blob/v1.29.2+k3s1/pkg/daemons/control/deps/deps.go#L235-L263
#    and saved at /var/lib/rancher/k3s/server/cred/passwd
mkdir -p /vagrant/tmp
python3 - <<EOF
import base64
import yaml

d = yaml.load(open('/etc/rancher/k3s/k3s.yaml', 'r'), Loader=yaml.FullLoader)

# save cluster ca certificate.
for c in d['clusters']:
    open(f"/vagrant/tmp/{c['name']}-ca-crt.pem", 'wb').write(base64.b64decode(c['cluster']['certificate-authority-data']))

# save user client certificates.
for u in d['users']:
    open(f"/vagrant/tmp/{u['name']}-crt.pem", 'wb').write(base64.b64decode(u['user']['client-certificate-data']))
    open(f"/vagrant/tmp/{u['name']}-key.pem", 'wb').write(base64.b64decode(u['user']['client-key-data']))
    print(f"Kubernetes API Server $k3s_url user {u['name']} client certificate in tmp/{u['name']}-*.pem")

# set the api-server server.
for c in d['clusters']:
    c['cluster']['server'] = '$k3s_url'

yaml.dump(d, open('/vagrant/tmp/admin.conf', 'w'), default_flow_style=False)
EOF

# show cluster-info.
kubectl cluster-info

# list etcd members.
etcdctl --write-out table member list

# show the endpoint status.
etcdctl --write-out table endpoint status

# list nodes.
kubectl get nodes -o wide

# rbac info.
kubectl get serviceaccount --all-namespaces
kubectl get role --all-namespaces
kubectl get rolebinding --all-namespaces
kubectl get rolebinding --all-namespaces -o json | jq .items[].subjects
kubectl get clusterrole --all-namespaces
kubectl get clusterrolebinding --all-namespaces
kubectl get clusterrolebinding --all-namespaces -o json | jq .items[].subjects

# rbac access matrix.
# see https://github.com/corneliusweig/rakkess/blob/master/doc/USAGE.md
kubectl krew install access-matrix
kubectl access-matrix version --full
kubectl access-matrix # at cluster scope.
kubectl access-matrix --namespace default
kubectl access-matrix --sa kubernetes-dashboard --namespace kubernetes-dashboard

# list system secrets.
kubectl -n kube-system get secret

# list all objects.
# NB without this hugly redirect the kubectl output will be all messed
#    when used from a vagrant session.
kubectl get all --all-namespaces

# really get all objects.
# see https://github.com/corneliusweig/ketall/blob/master/doc/USAGE.md
kubectl krew install get-all
kubectl get-all

# list services.
kubectl get svc

# list running pods.
kubectl get pods --all-namespaces -o wide

# list runnnig pods.
crictl pods

# list running containers.
crictl ps
ctr containers ls

# show listening ports.
ss -n --tcp --listening --processes

# show network routes.
ip route

# list wireguard peers.
wg

# show memory info.
free

# show versions.
kubectl version --output=yaml
crictl version
ctr version
