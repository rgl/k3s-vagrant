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
zot_version = '2.0.0-rc4'

# see https://get.k3s.io/
# see https://update.k3s.io/v1-release/channels
# see https://github.com/k3s-io/k3s/releases
k3s_channel = 'latest'
# renovate: datasource=github-releases depName=k3s-io/k3s extractVersion=(?<version>1\.26\..+)
k3s_version = 'v1.26.4+k3s1'

# see https://github.com/kube-vip/kube-vip/releases
# renovate: datasource=github-releases depName=kube-vip/kube-vip
kube_vip_version = 'v0.6.4'

# see https://github.com/helm/helm/releases
# renovate: datasource=github-releases depName=helm/helm
helm_version = 'v3.13.2'

# see https://github.com/roboll/helmfile/releases
# renovate: datasource=github-releases depName=roboll/helmfile
helmfile_version = 'v0.144.0'

# see https://github.com/kubernetes/dashboard/releases
# renovate: datasource=github-releases depName=kubernetes/dashboard
k8s_dashboard_version = 'v2.7.0'

# see https://github.com/derailed/k9s/releases
# renovate: datasource=github-releases depName=derailed/k9s
k9s_version = 'v0.29.1'

# see https://github.com/kubernetes-sigs/krew/releases
# renovate: datasource=github-releases depName=kubernetes-sigs/krew
krew_version = 'v0.4.4'

# see https://github.com/etcd-io/etcd/releases
# NB make sure you use a version compatible with k3s.
# renovate: datasource=github-releases depName=etcd-io/etcd
etcdctl_version = 'v3.5.11'

# see https://artifacthub.io/packages/helm/bitnami/metallb
# renovate: datasource=helm depName=metallb registryUrl=https://charts.bitnami.com/bitnami
metallb_chart_version = '4.7.16'

# see https://gitlab.com/gitlab-org/charts/gitlab-runner/-/tags
# renovate: datasource=helm depName=gitlab-runner registryUrl=https://charts.gitlab.io
gitlab_runner_chart_version = '0.59.2'

# link to the gitlab-vagrant environment (https://github.com/rgl/gitlab-vagrant running at ../gitlab-vagrant).
gitlab_fqdn = 'gitlab.example.com'
gitlab_ip = '10.10.9.99'

# set the flannel backend. use one of:
# * host-gw:          non-secure network (needs ethernet (L2) connectivity between nodes).
# * vxlan:            non-secure network (needs UDP (L3) connectivity between nodes).
# * wireguard-native: secure network (needs UDP (L3) connectivity between nodes).
flannel_backend = 'host-gw'
#flannel_backend = 'vxlan'
#flannel_backend = 'wireguard-native'

number_of_server_nodes  = 3
number_of_agent_nodes   = 2

bridge_name           = nil
registry_fqdn         = 'registry.example.test'
registry_ip           = '10.11.0.4'
server_fqdn           = 's.example.test'
server_vip            = '10.11.0.30'
first_server_node_ip  = '10.11.0.31'
first_agent_node_ip   = '10.11.0.41'
lb_ip_range           = '10.11.0.50-10.11.0.69'

# connect to the physical network through the host br-lan bridge.
# bridge_name           = 'br-lan'
# registry_ip           = '192.168.1.4'
# server_vip            = '192.168.1.30'
# first_server_node_ip  = '192.168.1.31'
# first_agent_node_ip   = '192.168.1.41'
# lb_ip_range           = '192.168.1.50-192.168.1.69'

server_nodes  = generate_nodes(first_server_node_ip, number_of_server_nodes, 's')
agent_nodes   = generate_nodes(first_agent_node_ip, number_of_agent_nodes, 'a')
k3s_token     = get_or_generate_k3s_token

extra_hosts = """
#{registry_ip} #{registry_fqdn}
#{server_vip} #{server_fqdn}
#{gitlab_ip} #{gitlab_fqdn}
"""

Vagrant.configure(2) do |config|
  config.vm.box = 'debian-11-amd64'

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
    config.vm.hostname = registry_fqdn
    if bridge_name
      config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: bridge_name, ip: registry_ip, auto_config: false
      config.vm.provision 'shell', path: 'provision-network.sh', args: [registry_ip]
      config.vm.provision 'reload'
    else
      config.vm.network :private_network, ip: registry_ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    end
    config.vm.provision 'shell', path: 'provision-base.sh', args: [extra_hosts]
    config.vm.provision 'shell', path: 'provision-zot.sh', args: [zot_version]
  end

  server_nodes.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 2*1024
      end
      config.vm.hostname = fqdn
      if bridge_name
        config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: bridge_name, ip: ip_address, auto_config: false
        config.vm.provision 'shell', path: 'provision-network.sh', args: [ip_address]
        config.vm.provision 'reload'
      else
        config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      end
      config.vm.provision 'shell', path: 'provision-base.sh', args: [extra_hosts]
      config.vm.provision 'shell', path: 'provision-wireguard.sh'
      config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [etcdctl_version]
      config.vm.provision 'shell', path: 'provision-k3s-registries.sh'
      config.vm.provision 'shell', path: 'provision-k3s-server.sh', args: [
        n == 1 ? "cluster-init" : "cluster-join",
        k3s_channel,
        k3s_version,
        k3s_token,
        flannel_backend,
        ip_address,
        krew_version,
        number_of_agent_nodes > 0 && '1' || '0',
      ]
      config.vm.provision 'shell', path: 'provision-helm.sh', args: [helm_version] # NB this might not really be needed, as rancher has a HelmChart CRD.
      config.vm.provision 'shell', path: 'provision-helmfile.sh', args: [helmfile_version]
      config.vm.provision 'shell', path: 'provision-k9s.sh', args: [k9s_version]
      if n == 1
        config.vm.provision 'shell', path: 'provision-kube-vip.sh', args: [kube_vip_version, server_vip]
        config.vm.provision 'shell', path: 'provision-metallb.sh', args: [metallb_chart_version, lb_ip_range]
        config.vm.provision 'shell', path: 'provision-k8s-dashboard.sh', args: [k8s_dashboard_version]
        config.vm.provision 'shell', path: 'provision-gitlab-runner.sh', args: [gitlab_runner_chart_version, gitlab_fqdn, gitlab_ip]
      end
    end
  end

  agent_nodes.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 2*1024
      end
      config.vm.hostname = fqdn
      if bridge_name
        config.vm.network :public_network, mode: 'bridge', type: 'bridge', dev: bridge_name, ip: ip_address, auto_config: false
        config.vm.provision 'shell', path: 'provision-network.sh', args: [ip_address]
        config.vm.provision 'reload'
      else
        config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      end
      config.vm.provision 'shell', path: 'provision-base.sh', args: [extra_hosts]
      config.vm.provision 'shell', path: 'provision-wireguard.sh'
      config.vm.provision 'shell', path: 'provision-k3s-registries.sh'
      config.vm.provision 'shell', path: 'provision-k3s-agent.sh', args: [
        k3s_channel,
        k3s_version,
        k3s_token,
        ip_address
      ]
    end
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 's1'
    trigger.run = {
      inline: '''bash -euc \'
install -d tmp
artifacts=(
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.pem
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.der
  ../gitlab-vagrant/tmp/gitlab-runners-registration-token.txt
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
