#!/bin/bash
set -euo pipefail

#
# deploy helmfile.

helmfile_version="${1:-v0.144.0}"; shift || true

# install helmfile.
# see https://github.com/roboll/helmfile#installation
echo "installing helmfile $helmfile_version..."
case `uname -m` in
    x86_64)
        wget -qOhelmfile "https://github.com/roboll/helmfile/releases/download/$helmfile_version/helmfile_linux_amd64"
        ;;
    armv7l)
        wget -qOhelmfile "https://github.com/roboll/helmfile/releases/download/$helmfile_version/helmfile_linux_arm64"
        ;;
esac
install helmfile /usr/local/bin
rm helmfile

# kick the tires.
printf "#\n# helmfile version\n#\n"
helmfile version
