#!/bin/bash
set -euxo pipefail

ip_address="$1"; shift || true

# disable ipv6.
cat >/etc/sysctl.d/99-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
EOF
sysctl -p -f /etc/sysctl.d/99-ipv6.conf

# set network.
# NB the system must be rebooted for this to take effect. this is required when
#    running by vagrant, since we cannot reconfigure the network under it.
#    instead, we reboot the machine from a vagrant provisioner.
cat >/etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
  address $ip_address
  netmask 255.255.255.0
EOF
