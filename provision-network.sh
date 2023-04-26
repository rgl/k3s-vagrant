#!/bin/bash
set -euxo pipefail

ip_address="$1"; shift || true
gw_ip_address="$(ip route | awk '/default/ {print $3}')"

# disable ipv6.
cat >/etc/sysctl.d/99-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
EOF
sysctl -p -f /etc/sysctl.d/99-ipv6.conf

# set network.
ifdown eth1
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
  post-up ip route add default via $gw_ip_address
  post-down ip route del default via $gw_ip_address
EOF
ifup eth1
