#!/bin/bash
set -eux

k9s_version="${1:-v0.17.5}"; shift

# download and install.
wget -qO- "https://github.com/derailed/k9s/releases/download/$k9s_version/k9s_Linux_x86_64.tar.gz" \
  | tar xzf - k9s
install -m 755 k9s /usr/local/bin/
rm k9s

# try it.
k9s version
