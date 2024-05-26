# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

# enable typed triggers.
# NB this is needed to modify the libvirt domain scsi controller model to virtio-scsi.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

require 'ipaddr'
require 'open3'

def get_or_generate_k3s_token
  # TODO generate an unique random an cache it.
  # generated with openssl rand -hex 32
  '7e982a7bbac5f385ecbb988f800787bc9bb617552813a63c4469521c53d83b6e'
end

def generate_nodes(first_ip_address, count, name_prefix)
  ip_addr = IPAddr.new first_ip_address
  (1..count).map do |n|
    ip_address, ip_addr = ip_addr.to_s, ip_addr.succ
    name = "#{name_prefix}#{n}"
    fqdn = "#{name}.example.test"
    [name, fqdn, ip_address, n]
  end
end

# see https://github.com/project-zot/zot/releases
# renovate: datasource=github-releases depName=project-zot/zot
ZOT_VERSION = '2.0.4'

# see https://get.k3s.io/
# see https://update.k3s.io/v1-release/channels
# see https://github.com/k3s-io/k3s/releases
K3S_CHANNEL = 'latest'
# renovate: datasource=github-releases depName=k3s-io/k3s extractVersion=(?<version>1\.29\..+)
K3S_VERSION = 'v1.29.4+k3s1'

# see https://github.com/kube-vip/kube-vip/releases
# renovate: datasource=github-releases depName=kube-vip/kube-vip
KUBE_VIP_VERSION = 'v0.8.0'

# see https://github.com/helm/helm/releases
# renovate: datasource=github-releases depName=helm/helm
HELM_VERSION = 'v3.15.1'

# see https://github.com/helmfile/helmfile/releases
# renovate: datasource=github-releases depName=helmfile/helmfile
HELMFILE_VERSION = '0.164.0'

# see https://github.com/kubernetes/dashboard/releases
# renovate: datasource=helm depName=kubernetes-dashboard registryUrl=https://kubernetes.github.io/dashboard
K8S_DASHBOARD_CHART_VERSION = 'v7.4.0'

# see https://github.com/derailed/k9s/releases
# renovate: datasource=github-releases depName=derailed/k9s
K9S_VERSION = 'v0.32.4'

# see https://github.com/kubernetes-sigs/krew/releases
# renovate: datasource=github-releases depName=kubernetes-sigs/krew
KREW_VERSION = 'v0.4.4'

# see https://github.com/etcd-io/etcd/releases
# NB make sure you use a version compatible with k3s.
# renovate: datasource=github-releases depName=etcd-io/etcd
ETCDCTL_VERSION = 'v3.5.13'

# see https://artifacthub.io/packages/helm/bitnami/metallb
# renovate: datasource=helm depName=metallb registryUrl=https://charts.bitnami.com/bitnami
METALLB_CHART_VERSION = '6.2.1' # app version: 0.14.5

# see https://gitlab.com/gitlab-org/charts/gitlab-runner/-/tags
# renovate: datasource=helm depName=gitlab-runner registryUrl=https://charts.gitlab.io
GITLAB_RUNNER_CHART_VERSION = '0.63.0'

# link to the gitlab-vagrant environment (https://github.com/rgl/gitlab-vagrant running at ../gitlab-vagrant).
GITLAB_FQDN = 'gitlab.example.com'
GITLAB_IP = '10.10.9.99'

# see https://github.com/argoproj/argo-cd/releases
# renovate: datasource=github-releases depName=argoproj/argo-cd
ARGOCD_CLI_VERSION = '2.11.0'

# see https://artifacthub.io/packages/helm/argo/argo-cd
# see https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
# renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
ARGOCD_CHART_VERSION = '6.9.3' # app version 2.11.0.

# see https://artifacthub.io/packages/helm/crossplane/crossplane
# see https://github.com/crossplane/crossplane/tree/master/cluster/charts/crossplane
# see https://github.com/crossplane/crossplane/releases
# renovate: datasource=github-releases depName=crossplane/crossplane
CROSSPLANE_CHART_VERSION = '1.16.0' # app version 1.16.0.

# see https://marketplace.upbound.io/providers/upbound/provider-aws-s3
# see https://github.com/upbound/provider-aws
# renovate: datasource=github-releases depName=upbound/provider-aws
CROSSPLANE_PROVIDER_AWS_S3_VERSION = '1.4.0'

# set the flannel backend. use one of:
# * host-gw:          non-secure network (needs ethernet (L2) connectivity between nodes).
# * vxlan:            non-secure network (needs UDP (L3) connectivity between nodes).
# * wireguard-native: secure network (needs UDP (L3) connectivity between nodes).
FLANNEL_BACKEND = 'host-gw'
#FLANNEL_BACKEND = 'vxlan'
#FLANNEL_BACKEND = 'wireguard-native'

NUMBER_OF_SERVER_NODES  = 1
NUMBER_OF_AGENT_NODES   = 1

BRIDGE_NAME           = nil
REGISTRY_FQDN         = 'registry.example.test'
REGISTRY_IP           = '10.11.0.4'
SERVER_FQDN           = 's.example.test'
SERVER_VIP            = '10.11.0.30'
FIRST_SERVER_NODE_IP  = '10.11.0.31'
FIRST_AGENT_NODE_IP   = '10.11.0.41'
LB_IP_RANGE           = '10.11.0.50-10.11.0.69'

# connect to the physical network through the host br-lan bridge.
# BRIDGE_NAME           = 'br-lan'
# REGISTRY_IP           = '192.168.1.4'
# SERVER_VIP            = '192.168.1.30'
# FIRST_SERVER_NODE_IP  = '192.168.1.31'
# FIRST_AGENT_NODE_IP   = '192.168.1.41'
# LB_IP_RANGE           = '192.168.1.50-192.168.1.69'

SERVER_NODES  = generate_nodes(FIRST_SERVER_NODE_IP, NUMBER_OF_SERVER_NODES, 's')
AGENT_NODES   = generate_nodes(FIRST_AGENT_NODE_IP, NUMBER_OF_AGENT_NODES, 'a')
K3S_TOKEN     = get_or_generate_k3s_token

EXTRA_HOSTS = """
#{REGISTRY_IP} #{REGISTRY_FQDN}
#{SERVER_VIP} #{SERVER_FQDN}
#{GITLAB_IP} #{GITLAB_FQDN}
"""

# provision common tools between servers and agents.
def provision_common(config, role, n)
  config.vm.provision 'shell', path: 'provision-helm.sh', args: [HELM_VERSION] # NB k3s also has a HelmChart CRD.
  config.vm.provision 'shell', path: 'provision-helmfile.sh', args: [HELMFILE_VERSION]
  config.vm.provision 'shell', path: 'provision-k9s.sh', args: [K9S_VERSION]
end

# provision the user workloads when running in the last agent or server (iif
# there are no agents).
def provision_user_workloads(config, role, n)
  if (role == 'agent' && n == NUMBER_OF_AGENT_NODES) || (role == 'server' && n == NUMBER_OF_SERVER_NODES && NUMBER_OF_AGENT_NODES == 0) then
    env = {
      'KUBECONFIG' => '/vagrant/tmp/admin.conf',
    }
    config.vm.provision 'shell', path: 'provision-k8s-dashboard.sh', args: [K8S_DASHBOARD_CHART_VERSION], env: env
    config.vm.provision 'shell', path: 'provision-gitlab-runner.sh', args: [GITLAB_RUNNER_CHART_VERSION, GITLAB_FQDN, GITLAB_IP], env: env
    config.vm.provision 'shell', path: 'provision-argocd.sh', args: [ARGOCD_CLI_VERSION, ARGOCD_CHART_VERSION], env: env
    config.vm.provision 'shell', path: 'provision-crossplane.sh', args: [CROSSPLANE_CHART_VERSION, CROSSPLANE_PROVIDER_AWS_S3_VERSION], env: env
  end
end

Vagrant.configure(2) do |config|
  config.vm.box = 'debian-12-amd64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    lv.disk_bus = 'scsi'
    lv.disk_device = 'sda'
    lv.disk_driver :discard => 'unmap', :cache => 'unsafe'
    lv.machine_virtual_size = 16
    # NB vagrant-libvirt does not yet support urandom. but we'll modify this to
    #    urandom in the trigger bellow.
    lv.random :model => 'random'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
    config.trigger.before :'VagrantPlugins::ProviderLibvirt::Action::StartDomain', type: :action do |trigger|
      trigger.ruby do |env, machine|
        # modify the random model to use the urandom backend device.
        stdout, stderr, status = Open3.capture3(
          'virt-xml', machine.id,
          '--edit',
          '--rng', '/dev/urandom')
        if status.exitstatus != 0
          raise "failed to run virt-xml to modify the random backend device. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
        end
        # modify the scsi controller model to virtio-scsi.
        # see https://github.com/vagrant-libvirt/vagrant-libvirt/pull/692
        # see https://github.com/vagrant-libvirt/vagrant-libvirt/issues/999
        stdout, stderr, status = Open3.capture3(
          'virt-xml', machine.id,
          '--edit', 'type=scsi',
          '--controller', 'model=virtio-scsi')
        if status.exitstatus != 0
          raise "failed to run virt-xml to modify the scsi controller model. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
        end
      end
    end
  end

  config.vm.define 'registry' do |config|
    config.vm.provider 'libvirt' do |lv, config|
      lv.memory = 2*1024
    end
    config.vm.hostname = REGISTRY_FQDN
    if BRIDGE_NAME
      config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: BRIDGE_NAME, ip: REGISTRY_IP, auto_config: false
      config.vm.provision 'shell', path: 'provision-network.sh', args: [REGISTRY_IP]
      config.vm.provision 'reload'
    else
      config.vm.network :private_network, ip: REGISTRY_IP, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    end
    config.vm.provision 'shell', path: 'provision-base.sh', args: [EXTRA_HOSTS]
    config.vm.provision 'shell', path: 'provision-zot.sh', args: [ZOT_VERSION]
  end

  SERVER_NODES.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 2*1024
      end
      config.vm.hostname = fqdn
      if BRIDGE_NAME
        config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: BRIDGE_NAME, ip: ip_address, auto_config: false
        config.vm.provision 'shell', path: 'provision-network.sh', args: [ip_address]
        config.vm.provision 'reload'
      else
        config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      end
      config.vm.provision 'shell', path: 'provision-base.sh', args: [EXTRA_HOSTS]
      config.vm.provision 'shell', path: 'provision-wireguard.sh'
      config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [ETCDCTL_VERSION]
      config.vm.provision 'shell', path: 'provision-containerd-shim-spin-v2.sh'
      config.vm.provision 'shell', path: 'provision-containerd-configuration.sh'
      config.vm.provision 'shell', path: 'provision-k3s-registries.sh'
      config.vm.provision 'shell', path: 'provision-k3s-server.sh', args: [
        n == 1 ? "cluster-init" : "cluster-join",
        K3S_CHANNEL,
        K3S_VERSION,
        K3S_TOKEN,
        FLANNEL_BACKEND,
        ip_address,
        KREW_VERSION,
        NUMBER_OF_AGENT_NODES > 0 && '1' || '0',
      ]
      provision_common(config, 'server', n)
      if n == 1
        config.vm.provision 'shell', path: 'provision-kube-vip.sh', args: [KUBE_VIP_VERSION, SERVER_VIP]
        config.vm.provision 'shell', path: 'provision-metallb.sh', args: [METALLB_CHART_VERSION, LB_IP_RANGE]
      end
      provision_user_workloads(config, 'server', n)
    end
  end

  AGENT_NODES.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 2*1024
      end
      config.vm.hostname = fqdn
      if BRIDGE_NAME
        config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: BRIDGE_NAME, ip: ip_address, auto_config: false
        config.vm.provision 'shell', path: 'provision-network.sh', args: [ip_address]
        config.vm.provision 'reload'
      else
        config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      end
      config.vm.provision 'shell', path: 'provision-base.sh', args: [EXTRA_HOSTS]
      config.vm.provision 'shell', path: 'provision-wireguard.sh'
      config.vm.provision 'shell', path: 'provision-containerd-shim-spin-v2.sh'
      config.vm.provision 'shell', path: 'provision-containerd-configuration.sh'
      config.vm.provision 'shell', path: 'provision-k3s-registries.sh'
      config.vm.provision 'shell', path: 'provision-k3s-agent.sh', args: [
        K3S_CHANNEL,
        K3S_VERSION,
        K3S_TOKEN,
        ip_address
      ]
      provision_common(config, 'agent', n)
      provision_user_workloads(config, 'agent', n)
    end
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'registry'
    trigger.run = {
      inline: '''bash -euc \'
install -d tmp
artifacts=(
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.pem
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.der
  ../gitlab-vagrant/tmp/gitlab-runner-authentication-token-kubernetes-k3s.json
)
for artifact in "${artifacts[@]}"; do
  if [ -f $artifact ]; then
    rsync $artifact tmp
  fi
done
\'
'''
    }
  end
end
