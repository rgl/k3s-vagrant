# k3s-vagrant
# Usage

Configure your hosts file with:

```
10.11.0.101 s1.example.test
10.11.0.101 traefik-dashboard.example.test
10.11.0.101 kubernetes-dashboard.example.test
```

Install the base [debian vagrant box](https://github.com/rgl/debian-vagrant).

Install the required vagrant plugins:

```bash
vagrant plugin install vagrant-hosts
```

Launch the environment:

```bash
time vagrant up --provider=libvirt # or --provider=virtualbox
```

## Traefik Dashboard

Access the Traefik Dashboard at:

    http://traefik-dashboard.example.test

## Rancher Server

Access the Rancher Server at:

    https://s1.example.test:6443

**NB** This is a proxy to the k8s API server (which is running in port 6444).

The default `admin` user password is outputted to the vagrant output.

You can also get it from the `tmp/admin-password.txt` file or the
`/etc/rancher/k3s/k3s.yaml` (inside the `s1` machine) file.

## Kubernetes Dashboard

Launch the kubernetes API server proxy in background:

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl proxy &
```

Then access the kubernetes dashboard at:

    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

Then select `Token` and use the contents of `tmp/admin-token.txt` as the token.

Instead of using the kubectl proxy, you can also access the Kubernetes Dashboard at:

    https://kubernetes-dashboard.example.test

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
* [k3s Configuration](https://rancher.com/docs/k3s/latest/en/configuration/)
* [k3s Under the Hood: Building a Product-grade Lightweight Kubernetes Distro (KubeCon NA 2019)](https://www.youtube.com/watch?v=-HchRyqNtkU)
