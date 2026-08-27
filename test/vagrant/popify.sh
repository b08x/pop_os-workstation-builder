#!/usr/bin/env bash
# SPDX-License-Identifier: MIT-0
# ============================================================================
# Bring a stock Ubuntu 24.04 Vagrant box close enough to Pop!_OS that
# playbooks/workstation.yml is testing something real.
#
# Runs as root, once, before the ansible provisioner. Everything here is
# scaffolding the collection itself is not responsible for: the target account,
# disk headroom, and the System76 archive that makes pop-* and system76-*
# packages resolvable.
# ============================================================================
set -euo pipefail

TARGET_USER="${TARGET_USER:-b08x}"

log() { printf '[popify] %s\n' "$*"; }

# --- disk ------------------------------------------------------------------
# The box ships a 10G root. libvirt was told to hand out a larger backing file;
# nothing in the guest grows into it on its own.
grow_root() {
  local part_dev root_dev part_num

  # growpart lives in cloud-guest-utils, which the bento boxes omit.
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cloud-guest-utils

  part_dev="$(findmnt -no SOURCE /)"
  root_dev="/dev/$(lsblk -no PKNAME "${part_dev}")"
  part_num="$(< "/sys/class/block/$(basename "${part_dev}")/partition")"

  log "growing ${part_dev} into ${root_dev}"
  growpart "${root_dev}" "${part_num}" || log "partition already at full size"
  resize2fs "${part_dev}" || log "filesystem already at full size"
}

# --- target account --------------------------------------------------------
# hosts.ini connects as this user and group_vars sets workstation_user to it.
# It inherits vagrant's authorized_keys so the key Vagrant already passes to
# ansible-playbook works without any extra key management.
create_target_user() {
  if id -u "${TARGET_USER}" >/dev/null 2>&1; then
    log "user ${TARGET_USER} already exists"
  else
    log "creating ${TARGET_USER}"
    useradd --create-home --shell /bin/bash --groups sudo "${TARGET_USER}"
  fi

  install -d -m 0700 -o "${TARGET_USER}" -g "${TARGET_USER}" \
    "/home/${TARGET_USER}/.ssh"
  install -m 0600 -o "${TARGET_USER}" -g "${TARGET_USER}" \
    /home/vagrant/.ssh/authorized_keys \
    "/home/${TARGET_USER}/.ssh/authorized_keys"

  # The playbooks are run without -K, so escalation must not prompt.
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TARGET_USER}" \
    > "/etc/sudoers.d/90-${TARGET_USER}"
  chmod 0440 "/etc/sudoers.d/90-${TARGET_USER}"
}

# --- System76 archive ------------------------------------------------------
# Pop!_OS is Ubuntu plus this archive. Adding it is what makes an apt candidate
# exist for pop-desktop, system76-driver, system76-power and friends, so the
# hardware and desktop roles exercise their real code paths instead of
# skipping on "no installation candidate".
add_pop_archive() {
  if [[ -f /etc/apt/sources.list.d/system76-ubuntu-pop-noble.list ]]; then
    log "System76 archive already present"
    return
  fi
  log "adding ppa:system76/pop"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    software-properties-common ca-certificates gnupg
  add-apt-repository -y ppa:system76/pop
}

# --- ansible prerequisites -------------------------------------------------
# bootstrap.yml installs these itself, but it needs python3 and a reachable
# sshd to get far enough to do so.
install_ansible_prereqs() {
  log "installing python3, python3-apt, openssh-server"
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    python3 python3-apt openssh-server
  systemctl enable --now ssh.service
}

main() {
  grow_root
  create_target_user
  add_pop_archive
  install_ansible_prereqs
  log "guest ready; handing off to ansible"
}

main "$@"
