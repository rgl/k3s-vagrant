#!/bin/bash
set -euxo pipefail

# NB this is not really required. we only install it to have the wg tool to
#    quickly see the wireguard configuration.
apt-get install -y wireguard
