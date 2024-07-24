#!/bin/bash
set -euxo pipefail

terraform_version="${1:-1.9.2}"; shift || true

# install dependencies.
apt-get install -y unzip

# install terraform.
artifact_url="https://releases.hashicorp.com/terraform/$terraform_version/terraform_${terraform_version}_linux_amd64.zip"
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
unzip -o $artifact_path -d /usr/local/bin
rm $artifact_path
CHECKPOINT_DISABLE=1 terraform version
