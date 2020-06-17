#!/bin/bash
set -eu

#
# deploy helm.

helm_version="${1:-v3.2.4}"; shift || true

# install helm.
# see https://helm.sh/docs/intro/install/
echo "installing helm $helm_version client..."
case `uname -m` in
    x86_64)
        wget -qO- "https://get.helm.sh/helm-$helm_version-linux-amd64.tar.gz" | tar xzf - --strip-components=1 linux-amd64/helm
        ;;
    armv7l)
        wget -qO- "https://get.helm.sh/helm-$helm_version-linux-arm.tar.gz" | tar xzf - --strip-components=1 linux-arm/helm
        ;;
esac
install helm /usr/local/bin

# install the bash completion script.
apt-get install -y bash-completion
helm completion bash >/usr/share/bash-completion/completions/helm

# add chart repositories.
# see https://helm.sh/docs/intro/quickstart/
echo "adding repositories..."
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

# kick the tires.
printf "#\n# helm version\n#\n"
helm version
