#!/bin/bash
set -eux

k3s_version="${1:-v1.0.0}"; shift
k3s_token="$1"; shift
ip_address="$1"; shift
fqdn="$(hostname --fqdn)"

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

# install k3s.
# see server arguments at e.g. https://github.com/rancher/k3s/blob/v1.0.0/pkg/cli/cmds/server.go#L49
# or run k3s server --help
# see https://rancher.com/docs/k3s/latest/en/configuration/
curl -sfL https://raw.githubusercontent.com/rancher/k3s/$k3s_version/install.sh \
    | \
        INSTALL_K3S_VERSION="$k3s_version" \
        K3S_TOKEN="$k3s_token" \
        sh -s -- \
            server \
            --no-deploy traefik \
            --node-ip "$ip_address" \
            --cluster-cidr '10.12.0.0/16' \
            --service-cidr '10.13.0.0/16' \
            --cluster-dns '10.13.0.10' \
            --cluster-domain 'cluster.local' \
            --flannel-iface 'eth1'

# see the systemd unit.
systemctl cat k3s

# wait for this node to be Ready.
# e.g. s1     Ready    master   3m    v1.16.3-k3s.2
$SHELL -c 'node_name=$(hostname); echo "waiting for node $node_name to be ready..."; while [ -z "$(kubectl get nodes $node_name | grep -E "$node_name\s+Ready\s+")" ]; do sleep 3; done; echo "node ready!"'

# wait for the kube-dns pod to be Running.
# e.g. coredns-fb8b8dccf-rh4fg   1/1     Running   0          33m
$SHELL -c 'while [ -z "$(kubectl get pods --selector k8s-app=kube-dns --namespace kube-system | grep -E "\s+Running\s+")" ]; do sleep 3; done'

# install traefik as the k8s ingress controller.
# see https://docs.traefik.io/v1.7/configuration/api/
# see https://github.com/rancher/k3s/issues/350#issuecomment-511218588
# see https://github.com/rancher/k3s/blob/v1.0.0/scripts/download#L21
# see https://github.com/helm/charts/tree/master/stable/traefik
# see https://kubernetes-charts.storage.googleapis.com/traefik-1.77.1.tgz
echo 'patching traefik to expose its api/dashboard at http://traefik-dashboard.example.test...'
wget -q https://raw.githubusercontent.com/rancher/k3s/$k3s_version/manifests/traefik.yaml
apt-get install -y python3-yaml
python3 - <<'EOF'
import difflib
import io
import sys
import yaml

config_orig = open('traefik.yaml', 'r', encoding='utf-8').read()
d = yaml.load(config_orig)

# re-configure traefik to start the api/dashboard.
d['spec']['set']['dashboard.enabled'] = 'true'
d['spec']['set']['dashboard.domain'] = 'traefik-dashboard.example.test'

# show the differences and save the modified yaml file.
config = io.StringIO()
yaml.dump(d, config, default_flow_style=False)
config = config.getvalue()
sys.stdout.writelines(difflib.unified_diff(config_orig.splitlines(1), config.splitlines(1)))
open('traefik.yaml', 'w', encoding='utf-8').write(config)
EOF
kubectl -n kube-system apply -f traefik.yaml
rm traefik.yaml

# wait for the svclb-traefik pod to be Running.
# e.g. eca1ea99515cd       About an hour ago   Ready               svclb-traefik-kz562   kube-system         0
$SHELL -c 'while [ -z "$(crictl pods --label app=svclb-traefik | grep -E "\s+Ready\s+")" ]; do sleep 3; done'

# save kubeconfig and admin password in the host.
# NB the default users are generated at https://github.com/rancher/k3s/blob/99b8222e8df034b5450eaac9bd21abd5462b6d56/pkg/daemons/control/server.go#L437
#    and saved at /var/lib/rancher/k3s/server/cred/passwd. e.g.: the admin user is in the system:masters group:
#       553dd25ca860c634cc57746bebc1d5cf,admin,admin,system:masters
#    NB this file path corresponds to the k3s server --basic-auth-file argument.
# see https://docs.traefik.io/v1.7/configuration/api/
mkdir -p /vagrant/tmp
python3 - <<EOF
import yaml

d = yaml.load(open('/etc/rancher/k3s/k3s.yaml', 'r'))

# save user passwords.
for u in d['users']:
    open(f"/vagrant/tmp/{u['user']['username']}-password.txt", 'w').write(u['user']['password'])
    print(f"Kubernetes API Server https://$fqdn:6443 user {u['user']['username']} password {u['user']['password']}")

# set the server ip.
for c in d['clusters']:
    c['cluster']['server'] = 'https://$fqdn:6443'

yaml.dump(d, open('/vagrant/tmp/admin.conf', 'w'), default_flow_style=False)
EOF

# show cluster-info.
kubectl cluster-info

# list nodes.
kubectl get nodes -o wide

# list all objects.
# NB without this hugly redirect the kubectl output will be all messed
#    when used from a vagrant session.
kubectl get all --all-namespaces >/tmp/kubectl-$$.tmp; cat /tmp/kubectl-$$.tmp; rm /tmp/kubectl-$$.tmp

# list services.
kubectl get svc

# list running pods.
kubectl get pods --all-namespaces

# list runnnig pods.
crictl pods

# list running containers.
crictl ps
k3s ctr containers ls

# show listening ports.
ss -n --tcp --listening --processes

# show network routes.
ip route

# show memory info.
free

# show versions.
kubectl version
crictl version
k3s ctr version
