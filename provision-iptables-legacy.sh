#!/bin/bash
set -euxo pipefail

# use iptables-legacy.
# see https://rancher.com/docs/k3s/latest/en/advanced/#enabling-legacy-iptables-on-raspbian-buster
apt-get install -y --no-install-recommends iptables
iptables -V
iptables -F
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
iptables -V
