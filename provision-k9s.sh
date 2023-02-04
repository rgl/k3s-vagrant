#!/bin/bash
set -euxo pipefail

k9s_version="${1:-v0.27.2}"; shift || true

# download and install.
wget -qO- "https://github.com/derailed/k9s/releases/download/$k9s_version/k9s_Linux_amd64.tar.gz" \
  | tar xzf - k9s
install -m 755 k9s /usr/local/bin/
rm k9s

# try it.
k9s version
