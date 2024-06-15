#!/bin/bash
set -euo pipefail

#
# deploy helmfile.

helmfile_version="${1:-0.165.0}"; shift || true

# install helmfile.
# see https://github.com/helmfile/helmfile#installation
echo "installing helmfile $helmfile_version..."
case `uname -m` in
    x86_64)
        wget -qO- "https://github.com/helmfile/helmfile/releases/download/v$helmfile_version/helmfile_${helmfile_version}_linux_amd64.tar.gz" | tar xzf - --strip-components=0 helmfile
        ;;
    aarch64)
        wget -qO- "https://github.com/helmfile/helmfile/releases/download/v$helmfile_version/helmfile_${helmfile_version}_linux_arm64.tar.gz" | tar xzf - --strip-components=0 helmfile
        ;;
esac
install helmfile /usr/local/bin
rm helmfile

# kick the tires.
printf "#\n# helmfile version\n#\n"
helmfile version
