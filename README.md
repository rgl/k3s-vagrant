# About

This is a [k3s](https://github.com/k3s-io/k3s) kubernetes cluster playground wrapped in a Vagrant environment.

# Usage

Configure the host machine `hosts` file with:

```
10.11.0.4  registry.example.test
10.11.0.10 s.example.test
10.11.0.50 traefik.example.test
10.11.0.50 kubernetes-dashboard.example.test
```

Install the base [Debian 12 (Bookworm) vagrant box](https://github.com/rgl/debian-vagrant).

Optionally, start the [rgl/gitlab-vagrant](https://github.com/rgl/gitlab-vagrant) environment at `../gitlab-vagrant`. If you do this, this environment will have the [gitlab-runner helm chart](https://docs.gitlab.com/runner/install/kubernetes.html) installed in the k8s cluster.

Optionally, connect the environment to the physical network through the host `br-lan` bridge. The environment assumes that the host bridge was configured as:

```bash
sudo -i
# review the configuration in the files at /etc/netplan and replace them all
# with a single configuration file:
ls -laF /etc/netplan
upstream_interface=eth0
upstream_mac=$(ip link show $upstream_interface | perl -ne '/ether ([^ ]+)/ && print $1')
cat >/etc/netplan/00-config.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0: {}
  bridges:
    br-lan:
      # inherit the MAC address from the enslaved eth0 interface.
      # NB this is required in machines that have intel AMT with shared IP
      #    address to prevent announcing multiple MAC addresses (AMT and OS
      #    eth0) for the same IP address.
      macaddress: $upstream_mac
      #link-local: []
      dhcp4: false
      addresses:
        - 192.168.1.11/24
      routes:
        - to: default
          via: 192.168.1.254
      nameservers:
        addresses:
          - 192.168.1.254
        search:
          - lan
      interfaces:
        - $upstream_interface
EOF
netplan apply
```

And open the `Vagrantfile`, uncomment and edit the block that starts at
`bridge_name` with your specific network details. Also ensure that the
`hosts` file has the used IP addresses.

Launch the environment:

```bash
time vagrant up --no-destroy-on-error --no-tty --provider=libvirt
```

**NB** When the `number_of_agent_nodes` `Vagrantfile` variable value is above `0`, the server nodes (e.g. `s1`) are [tainted](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) to prevent them from executing non control-plane workloads. That kind of workload is executed in the agent nodes (e.g. `a1`).

Access the cluster from the host:

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl cluster-info
kubectl get nodes -o wide
```

Execute an [example workload](https://github.com/rgl/example-docker-buildx-go):

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl apply -f example.yml
kubectl rollout status deployment/example
kubectl get ingresses,services,pods,deployments
example_ip="$(kubectl get ingress/example -o json | jq -r .status.loadBalancer.ingress[0].ip)"
example_fqdn="$(kubectl get ingress/example -o json | jq -r .spec.rules[0].host)"
example_url="http://$example_fqdn"
curl --resolve "$example_fqdn:80:$example_ip" "$example_url"
echo "$example_ip $example_fqdn" | sudo tee -a /etc/hosts
curl "$example_url"
xdg-open "$example_url"
kubectl delete -f example.yml
```

Execute an [example WebAssembly (Wasm) Spin workload](https://github.com/rgl/spin-http-go-example):

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl apply -f example-spin.yml
kubectl rollout status deployment/example-spin
kubectl get ingresses,services,pods,deployments
example_spin_ip="$(kubectl get ingress/example-spin -o json | jq -r .status.loadBalancer.ingress[0].ip)"
example_spin_fqdn="$(kubectl get ingress/example-spin -o json | jq -r .spec.rules[0].host)"
example_spin_url="http://$example_spin_fqdn"
curl --resolve "$example_spin_fqdn:80:$example_spin_ip" "$example_spin_url"
echo "$example_spin_ip $example_spin_fqdn" | sudo tee -a /etc/hosts
curl "$example_spin_url"
xdg-open "$example_spin_url"
# NB unfortunately, the pod will be stuck in the Terminating state.
#    TODO https://github.com/deislabs/containerd-wasm-shims/issues/207
kubectl delete -f example-spin.yml
```

Execute an [example WebAssembly (Wasm) WasmEdge workload](https://github.com/rgl/wasmedge-http-rust-example):

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl apply -f example-wasmedge.yml
kubectl rollout status deployment/example-wasmedge
kubectl get ingresses,services,pods,deployments
example_wasmedge_ip="$(kubectl get ingress/example-wasmedge -o json | jq -r .status.loadBalancer.ingress[0].ip)"
example_wasmedge_fqdn="$(kubectl get ingress/example-wasmedge -o json | jq -r .spec.rules[0].host)"
example_wasmedge_url="http://$example_wasmedge_fqdn"
curl --resolve "$example_wasmedge_fqdn:80:$example_wasmedge_ip" "$example_wasmedge_url"
echo "$example_wasmedge_ip $example_wasmedge_fqdn" | sudo tee -a /etc/hosts
curl "$example_wasmedge_url"
xdg-open "$example_wasmedge_url"
# NB unfortunately, the pod will be stuck in the Terminating state.
#    TODO https://github.com/containerd/runwasi/issues/418
kubectl delete -f example-wasmedge.yml
```

List this repository dependencies (and which have newer versions):

```bash
export GITHUB_COM_TOKEN='YOUR_GITHUB_PERSONAL_TOKEN'
./renovate.sh
```

## Traefik Dashboard

Access the Traefik Dashboard at:

    https://traefik.example.test/dashboard/

## Rancher Server

Access the Rancher Server at:

    https://s.example.test:6443

**NB** This is a proxy to the k8s API server (which is running in port 6444).

**NB** You must use the client certificate that is inside the `tmp/admin.conf`,
`tmp/*.pem`, or `/etc/rancher/k3s/k3s.yaml` (inside the `s1` machine) file.

Access the rancher server using the client certificate with httpie:

```bash
http \
    --verify tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --cert-key tmp/default-key.pem \
    https://s.example.test:6443
```

Or with curl:

```bash
curl \
    --cacert tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --key tmp/default-key.pem \
    https://s.example.test:6443
```

## Kubernetes Dashboard

Access the Kubernetes Dashboard at:

    https://kubernetes-dashboard.example.test

Then select `Token` and use the contents of `tmp/admin-token.txt` as the token.

You can also launch the kubernetes API server proxy in background:

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl proxy &
```

And access the kubernetes dashboard at:

    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

## K9s Dashboard

The [K9s](https://github.com/derailed/k9s) console UI dashboard is also
installed in the server node. You can access it by running:

```bash
vagrant ssh s1
sudo su -l
k9s
```

## Zot Registry

The [Zot Registry](https://zotregistry.dev) is installed in the registry
node and can be accessed at:

http://registry.example.test

# Notes

* k3s has a custom k8s authenticator module that does user authentication from `/var/lib/rancher/k3s/server/cred/passwd`.

# Reference

* [k3s Installation and Configuration Options](https://rancher.com/docs/k3s/latest/en/installation/install-options/)
* [k3s Advanced Options and Configuration](https://rancher.com/docs/k3s/latest/en/advanced/)
* [k3s Under the Hood: Building a Product-grade Lightweight Kubernetes Distro (KubeCon NA 2019)](https://www.youtube.com/watch?v=-HchRyqNtkU)
