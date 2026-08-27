# -*- mode: ruby -*-
# vi: set ft=ruby :
# SPDX-License-Identifier: MIT-0
# ============================================================================
# b08x.workstation -- disposable Pop!_OS-alike test VM
#
# Provisions the `popvm` host that inventory/hosts.ini and
# inventory/host_vars/popvm.yml already describe, so a `vagrant up` rehearses
# the real playbook against the real inventory rather than a parallel one.
#
#   vagrant up                 # boot + bootstrap.yml + workstation.yml
#   vagrant provision          # re-run the playbooks (idempotence check)
#   vagrant destroy -f         # throw it away
#
# Requires:
#   vagrant plugin install vagrant-libvirt
#
# Fidelity notes -- read these before trusting a green run:
#   * The box is Ubuntu 24.04, not Pop!_OS. The playbook gates on
#     ansible_os_family == "Debian", so the assert passes unmodified. What
#     differs is APT candidate resolution, which the System76 PPA restores
#     for pop-* and system76-* packages (see test/vagrant/popify.sh).
#   * The box is MBR/BIOS-partitioned, so the kernelstub / systemd-boot path
#     that host_vars/popvm.yml wants to exercise does NOT run here. A real
#     UEFI Pop!_OS box built from the ISO is tracked separately.
# ============================================================================

VAGRANTFILE_API_VERSION = "2"

# --- knobs, all overridable from the environment ----------------------------
BOX          = ENV.fetch("POPVM_BOX",     "bento/ubuntu-24.04")
HOSTNAME     = ENV.fetch("POPVM_NAME",    "popvm")
IP           = ENV.fetch("POPVM_IP",      "192.168.41.42")
NET_NAME     = ENV.fetch("POPVM_NET",     "workstation-test")
MEMORY       = ENV.fetch("POPVM_MEMORY",  "8192").to_i
CPUS         = ENV.fetch("POPVM_CPUS",    "4").to_i
DISK_GB      = ENV.fetch("POPVM_DISK",    "40").to_i

# The account the collection provisions. Must match workstation_user in
# inventory/group_vars/workstations.yml and ansible_user in hosts.ini.
TARGET_USER  = ENV.fetch("POPVM_USER",    "b08x")

# Skip the ansible provisioner when you only want a bare guest to poke at.
RUN_ANSIBLE  = ENV.fetch("POPVM_PROVISION", "1") == "1"

unless Vagrant.has_plugin?("vagrant-libvirt")
  raise Vagrant::Errors::VagrantError.new, <<~MSG
    The vagrant-libvirt plugin is not installed.

        vagrant plugin install vagrant-libvirt

    This Vagrantfile targets libvirt/KVM deliberately: it is what the host
    already runs, and it is the only provider here that can eventually boot a
    real UEFI Pop!_OS image.
  MSG
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box      = BOX
  config.vm.hostname = HOSTNAME

  # Static address so inventory/hosts.ini needs no rewriting per boot.
  config.vm.network :private_network,
                    ip: IP,
                    libvirt__network_name: NET_NAME,
                    libvirt__netmask: "255.255.255.0",
                    libvirt__dhcp_enabled: false,
                    libvirt__forward_mode: "nat"

  # The collection installs a build toolchain and container images; the
  # default 10G box disk runs out well before workstation.yml finishes.
  config.vm.provider :libvirt do |lv|
    lv.memory              = MEMORY
    lv.cpus                = CPUS
    lv.machine_virtual_size = DISK_GB
    lv.cpu_mode            = "host-passthrough"
    lv.disk_bus            = "virtio"
    lv.nic_model_type      = "virtio"
    lv.graphics_type       = "none"
    lv.video_type          = "none"
  end

  # Keep the repo out of the guest. Ansible reaches in over SSH from the host,
  # which is how the real machines are provisioned.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # --- stage 1: make the guest look enough like Pop!_OS ---------------------
  config.vm.provision "popify",
                      type: "shell",
                      path: "test/vagrant/popify.sh",
                      env: { "TARGET_USER" => TARGET_USER },
                      privileged: true

  # --- stage 2: the actual thing under test --------------------------------
  if RUN_ANSIBLE
    %w[bootstrap workstation].each do |play|
      config.vm.provision "ansible-#{play}", type: "ansible" do |a|
        a.playbook       = "playbooks/#{play}.yml"
        a.inventory_path = "inventory/hosts.ini"
        a.limit          = HOSTNAME
        a.compatibility_mode = "2.0"
        a.raw_arguments  = ["--diff"]
      end
    end
  end
end
