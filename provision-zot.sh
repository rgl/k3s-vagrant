#!/bin/bash
set -euxo pipefail

zot_version="${1:-2.0.3}"

zot_domain="$(hostname --fqdn)"
zot_url="http://$zot_domain"

# NB you can see all the currently used container images with:
#     kubectl get pods --all-namespaces -o go-template --template '{{range .items}}{{range .spec.containers}}{{printf "%s\n" .image}}{{end}}{{end}}' | sort -u
registries='
docker.io
registry.k8s.io
ghcr.io
quay.io
registry.gitlab.com
'

# add the zot user.
groupadd --system zot
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup zot \
    --home /opt/zot \
    zot
install -m 750 -o zot -g zot -d /opt/zot

# download and install.
zot_dist_url="https://github.com/project-zot/zot/releases/download/v$zot_version/zot-linux-amd64"
zli_dist_url="https://github.com/project-zot/zot/releases/download/v$zot_version/zli-linux-amd64"
zot_dist_path="/vagrant/tmp/zot-$zot_version-$(basename "$zot_dist_url")"
zli_dist_path="/vagrant/tmp/zot-$zot_version-$(basename "$zli_dist_url")"
if [ ! -f "$zot_dist_path" ]; then
    wget -qO "$zot_dist_path" "$zot_dist_url"
fi
if [ ! -f "$zli_dist_path" ]; then
    wget -qO "$zli_dist_path" "$zli_dist_url"
fi
install -m 755 -d /opt/zot/bin
install -m 750 -g zot -d /opt/zot/conf
install -m 750 -o zot -g zot -d /opt/zot/data
install -m 755 "$zot_dist_path" /opt/zot/bin/zot
install -m 755 "$zli_dist_path" /opt/zot/bin/zli
ln -sf /opt/zot/bin/zli /usr/local/bin/zli

# # install the certificates.
# install -m 440 -g zot /vagrant/tmp/tls/example-ca/$zot_domain-crt.pem /opt/zot/conf/crt.pem
# install -m 440 -g zot /vagrant/tmp/tls/example-ca/$zot_domain-key.pem /opt/zot/conf/key.pem

# create the configuration file.
# NB examples:
#       # use the upstream registry.
#       regctl tag ls registry.k8s.io/pause
#       regctl image inspect registry.k8s.io/pause
#       # use the zot mirror registry.
#       regctl image export registry.test/mirror/registry.k8s.io/pause pause.tar
#       regctl image inspect registry.test/mirror/registry.k8s.io/pause
#       regctl tag ls registry.test/mirror/registry.k8s.io/pause
# see https://zotregistry.dev/v2.0.3/articles/mirroring/
# see https://zotregistry.dev/v2.0.3/admin-guide/admin-configuration/#syncing-and-mirroring-registries
cat >/opt/zot/conf/config.yaml <<EOF
storage:
  rootDirectory: /opt/zot/data
http:
  address: 0.0.0.0
  port: 80
  # realm: zot
  # tls:
  #   cert: /opt/zot/conf/crt.pem
  #   key: /opt/zot/conf/key.pem
log:
  level: debug
extensions:
  ui:
    enable: true
  metrics:
    enable: true
    prometheus:
      path: /metrics
  search:
    enable: true
    cve:
      updateInterval: 2h
  sync:
    enable: true
    registries:
EOF
for d in $registries; do
  cat >>/opt/zot/conf/config.yaml <<EOF
      - urls:
          - https://$d
        content:
          - prefix: "**"
            destination: /mirror/$d
        onDemand: true
        tlsVerify: true
EOF
done
/opt/zot/bin/zot verify /opt/zot/conf/config.yaml

# create and start the service.
cat >/etc/systemd/system/zot.service <<EOF
[Unit]
Description=OCI Distribution Registry
Documentation=https://github.com/project-zot/zot
After=network.target auditd.service local-fs.target

[Service]
Type=simple
ExecStart=/opt/zot/bin/zot serve /opt/zot/conf/config.yaml
Restart=on-failure
User=zot
Group=zot
LimitNOFILE=500000
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable zot
systemctl restart zot

# wait for zot the be ready.
systemctl is-active --quiet --wait zot
# TODO remove this while loop after the following issue is fixed:
#         https://github.com/project-zot/zot/issues/2188
while ! wget -q "$zot_url/v2/"; do sleep 1; done;

# configure zli.
zli completion bash >/usr/share/bash-completion/completions/zli
zli config add main "$zot_url"
zli config --list
zli image list --config main
