# About

This is a [k3s](https://github.com/k3s-io/k3s) kubernetes cluster playground wrapped in a Vagrant environment.

**NB** The `vxlan` flannel backend [seems to be broken in Debian 11](https://github.com/k3s-io/k3s/issues/3863).

# Usage

Configure your hosts file with:

```
10.11.0.101 s1.example.test
10.11.0.101 traefik.example.test
10.11.0.101 kubernetes-dashboard.example.test
```

Install the base [Debian 11 (Bullseye) vagrant box](https://github.com/rgl/debian-vagrant).

Install the required vagrant plugins:

```bash
# see https://github.com/hashicorp/vagrant/issues/12445#issuecomment-876566065
export CFLAGS='-I/opt/vagrant/embedded/include/ruby-3.0.0/ruby'
vagrant plugin install vagrant-hosts
```

Optionally, start the [rgl/gitlab-vagrant](https://github.com/rgl/gitlab-vagrant) environment at `../gitlab-vagrant`. If you do this, this environment will have the [gitlab-runner helm chart](https://docs.gitlab.com/runner/install/kubernetes.html) installed in the k8s cluster.

Launch the environment:

```bash
time vagrant up --no-destroy-on-error --no-tty --provider=libvirt # or --provider=virtualbox
```

**NB** The server nodes (e.g. `s1`) are [tainted](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) to prevent them from executing non control-plane workloads. That kind of workload is executed in the agent nodes (e.g. `a1`).

## Traefik Dashboard

Access the Traefik Dashboard at:

    https://traefik.example.test/dashboard/

## Rancher Server

Access the Rancher Server at:

    https://s1.example.test:6443

**NB** This is a proxy to the k8s API server (which is running in port 6444).

**NB** You must use the client certificate that is inside the `tmp/admin.conf`,
`tmp/*.pem`, or `/etc/rancher/k3s/k3s.yaml` (inside the `s1` machine) file.

Access the rancher server using the client certificate with httpie:

```bash
http \
    --verify tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --cert-key tmp/default-key.pem \
    https://s1.example.test:6443
```

Or with curl:

```bash
curl \
    --cacert tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --key tmp/default-key.pem \
    https://s1.example.test:6443
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

# Notes

* k3s has a custom k8s authenticator module that does user authentication from `/var/lib/rancher/k3s/server/cred/passwd`.

# Reference

* [k3s Installation and Configuration Options](https://rancher.com/docs/k3s/latest/en/installation/install-options/)
* [k3s Advanced Options and Configuration](https://rancher.com/docs/k3s/latest/en/advanced/)
* [k3s Under the Hood: Building a Product-grade Lightweight Kubernetes Distro (KubeCon NA 2019)](https://www.youtube.com/watch?v=-HchRyqNtkU)
