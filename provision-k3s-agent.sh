#!/bin/bash
set -euxo pipefail

k3s_channel="$1"; shift
k3s_version="$1"; shift
k3s_token="$1"; shift
ip_address="$1"; shift
k3s_url="https://s.$(hostname --domain):6443"

# configure the motd.
# NB this was generated at http://patorjk.com/software/taag/#p=display&f=Big&t=k3s%0Aagent.
#    it could also be generated with figlet.org.
cat >/etc/motd <<'EOF'

  _    ____
 | |  |___ \
 | | __ __) |___
 | |/ /|__ </ __|        _
 |   < ___) \__ \       | |
 |_|\_\____/|___/_ _ __ | |_
  / _` |/ _` |/ _ \ '_ \| __|
 | (_| | (_| |  __/ | | | |_
  \__,_|\__, |\___|_| |_|\__|
         __/ |
        |___/

EOF

# install k3s.
# see https://docs.k3s.io/reference/agent-config
curl -sfL https://raw.githubusercontent.com/k3s-io/k3s/$k3s_version/install.sh \
    | \
        INSTALL_K3S_CHANNEL="$k3s_channel" \
        INSTALL_K3S_VERSION="$k3s_version" \
        K3S_TOKEN="$k3s_token" \
        K3S_URL="$k3s_url" \
        sh -s -- \
            agent \
            --node-ip "$ip_address" \
            --flannel-iface 'eth1'

# see the systemd unit.
systemctl cat k3s-agent

# check whether this system has the k3s requirements.
# NB we ignore the result for now, because its bogus on debian 11.
#    see https://github.com/k3s-io/k3s/issues/3897
k3s check-config || true

# NB do not try to use kubectl on a agent node, as kubectl does not work on a
#    agent node without a proper kubectl configuration (which you could copy
#    from the server).

# install the bash completion scripts.
crictl completion bash >/usr/share/bash-completion/completions/crictl
kubectl completion bash >/usr/share/bash-completion/completions/kubectl

# list runnnig pods.
crictl pods

# list running containers.
crictl ps
ctr containers ls

# show listening ports.
ss -n --tcp --listening --processes

# show network routes.
ip route

# show memory info.
free

# show versions.
crictl version
ctr version
