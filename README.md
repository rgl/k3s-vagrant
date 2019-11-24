# k3s-vagrant
# Usage

Configure your hosts file with:

```
10.11.0.101 s1.example.test
10.11.0.101 traefik-dashboard.example.test
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

# Reference

* [k3s Installation and Configuration Options](https://rancher.com/docs/k3s/latest/en/installation/install-options/)
* [k3s Configuration](https://rancher.com/docs/k3s/latest/en/configuration/)
* [k3s Under the Hood: Building a Product-grade Lightweight Kubernetes Distro (KubeCon NA 2019)](https://www.youtube.com/watch?v=-HchRyqNtkU)
