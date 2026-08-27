#!/usr/bin/env bash
# SPDX-License-Identifier: MIT-0
# ============================================================================
# Step 2 of 3 -- run this INSIDE the freshly installed Pop!_OS guest, as the
# user you created during the install. Turns a normal installation into
# something Vagrant can drive.
#
# Copy it in and run it:
#   scp test/vagrant/box/prepare-box.sh vagrant@<guest-ip>:
#   ssh vagrant@<guest-ip> 'sudo bash prepare-box.sh'
#
# Or paste it into the guest console if sshd is not up yet -- that is the
# chicken-and-egg this script resolves.
# ============================================================================
set -euo pipefail

BOX_USER="${BOX_USER:-vagrant}"

# The well-known Vagrant insecure public key. Vagrant replaces it with a
# generated keypair on first boot, so it only ever grants access to a box
# that has not been booted yet.
INSECURE_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key'

log() { printf '[prepare-box] %s\n' "$*"; }

require_root() {
  [[ "${EUID}" -eq 0 ]] || { echo "run me with sudo" >&2; exit 1; }
  id -u "${BOX_USER}" >/dev/null 2>&1 \
    || { echo "user ${BOX_USER} does not exist -- create it during the Pop installer" >&2; exit 1; }
}

# --- ssh -------------------------------------------------------------------
# Pop's live ISO ships openssh-client but not openssh-server, and the
# installed system inherits that. Nothing can reach the box until this runs.
setup_ssh() {
  log "installing and enabling openssh-server"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server

  local home; home="$(getent passwd "${BOX_USER}" | cut -d: -f6)"
  install -d -m 0700 -o "${BOX_USER}" -g "${BOX_USER}" "${home}/.ssh"
  printf '%s\n' "${INSECURE_KEY}" > "${home}/.ssh/authorized_keys"
  chown "${BOX_USER}:${BOX_USER}" "${home}/.ssh/authorized_keys"
  chmod 0600 "${home}/.ssh/authorized_keys"

  # UseDNS on a NAT network costs ~10s per connection and Ansible opens many.
  cat > /etc/ssh/sshd_config.d/99-vagrant.conf <<'SSHD'
UseDNS no
GSSAPIAuthentication no
PubkeyAuthentication yes
SSHD
  systemctl enable ssh.service
}

# --- sudo ------------------------------------------------------------------
setup_sudo() {
  log "granting ${BOX_USER} passwordless sudo"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${BOX_USER}" > "/etc/sudoers.d/99-${BOX_USER}"
  chmod 0440 "/etc/sudoers.d/99-${BOX_USER}"
  # Ansible pipelining needs no tty.
  sed -i 's/^Defaults[[:space:]]*requiretty/# &/' /etc/sudoers || true
}

# --- keep the box a box ----------------------------------------------------
# A box that upgrades itself on first boot makes every test run
# non-reproducible and races apt against the base role.
quiesce_updates() {
  log "disabling unattended upgrades and the first-run wizard"
  systemctl disable --now unattended-upgrades.service 2>/dev/null || true
  systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
  # cosmic-initial-setup only fires on graphical login, which a test box never
  # does -- masked anyway so a stray console login cannot block provisioning.
  systemctl disable --now cosmic-initial-setup.service 2>/dev/null || true
}

# --- shrink ----------------------------------------------------------------
# Zeroing free space is what lets qemu-img/virt-sparsify give back the ~30G
# of unwritten disk. Skip it and the .box is 40G.
zero_free_space() {
  log "cleaning apt cache"
  apt-get clean
  rm -rf /var/lib/apt/lists/*

  log "clearing machine identity so each clone gets its own"
  truncate -s 0 /etc/machine-id
  rm -f /var/lib/dbus/machine-id
  ln -sf /etc/machine-id /var/lib/dbus/machine-id
  rm -f /etc/ssh/ssh_host_*  # regenerated on first boot

  log "zeroing free space -- this takes a while and is meant to end in ENOSPC"
  dd if=/dev/zero of=/EMPTY bs=1M status=none || true
  rm -f /EMPTY
  sync
}

main() {
  require_root
  setup_ssh
  setup_sudo
  quiesce_updates
  zero_free_space
  log "done -- shut the guest down now: sudo poweroff"
}

main "$@"
