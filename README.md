# Pop!_OS Workstation Builder (`pop_os-workstation-builder`)

**Automated zero-touch provisioning and system configuration for Pop!_OS and System76 hardware.**

---

## Overview

This repository provides modular, idempotent Ansible playbooks specifically built for **Pop!_OS** (Debian/Ubuntu LTS family). Unlike traditional RHEL image-building setups (e.g., OSBuild/OSTree), this architecture is engineered for live post-install provisioning over standard Pop!_OS installation media, leveraging System76's native hardware daemons, `systemd-boot`, and APT package management.

---

## 3-Layer Governance Model

To prevent tooling bloat and un-reproducible system state, this project strictly adheres to a three-layer responsibility hierarchy:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1 — Ansible (This Repository)      Root / System-Wide                 │
│ APT packages · system76 daemons · kernelstub EFIVARs · SELinux/AppArmor     │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 2 — yadm                           $HOME / User Identity              │
│ Shell (Zsh) · Editor (Neovim/VSCode) · Agent Configs · SSH/GPG · Tool Lists │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 3 — Per-Project Venv               Repo-Local / Ephemeral             │
│ Python (.venv via uv) · node_modules · Gemfile.lock · Project .env          │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **IMPORTANT**: No user-level AI tooling, global npm/bun packages, or cargo tools are installed as root by Ansible in Layer 1. Those belong strictly to Layer 2 declarative manifests managed by `yadm`.

---

## Repository Structure

```
pop_os-workstation-builder/
├── ansible.cfg              # Optimized SSH pipelining & fact caching
├── inventory/
│   └── hosts.ini            # Localhost provisioning Target
├── playbooks/
│   ├── bootstrap.yml        # Rapid zero-touch machine initial preparation
│   └── workstation.yml      # Master provisioning and orchestration playbook
├── roles/
│   ├── pop_base/            # Timezone, APT optimization, sysctl, core dumps
│   ├── pop_hardware/        # system76-driver, system76-power, & kernelstub
│   ├── pop_cosmic/          # COSMIC Desktop & Pop!_Shell tiling configuration
│   ├── podman_docker/       # Container engines & user group privileges
│   └── yadm_bootstrap/      # Handoff to Layer 2 dotfiles and manifest bootstrapper
└── vars/
    └── pop_os_packages.yml  # APT package taxonomies and component groupings
```

---

## Usage Instructions

### 1. Initial Bootstrap on a Fresh Pop!_OS Install

After installing Pop!_OS from official media, open a terminal and run:

```bash
# Ensure Git and Ansible are available
sudo apt update && sudo apt install -y git ansible

# Clone the repository
git clone https://github.com/b08x/pop_os-workstation-builder.git ~/.setup/pop_os-workstation-builder
cd ~/.setup/pop_os-workstation-builder

# Run the complete setup
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --ask-become-pass
```

### 2. Dry-Run Check

To view changes before applying:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --diff --check
```

---

## Architecture Highlights: Pop!_OS vs. RHEL

- **Bootloader Configuration (`kernelstub`)**: On UEFI systems, Pop!_OS does not use GRUB. All kernel options (e.g. NVIDIA DRM modesetting) are applied cleanly via System76's `kernelstub` command directly to EFIVARs and `systemd-boot`.
- **NVIDIA & GPU Management**: Relies on System76's integrated testing pipeline (`system76-driver-nvidia`, `system76-power`). Graphics profile switching (Integrated, Discrete, Hybrid, Compute) is handled via `system76-power` rather than conflicting third-party RPM or CUDA repos.
- **CPU & Latency Scheduling**: Uses `system76-scheduler` to automatically boost interactive thread priority and govern power states without custom cpupower Bash wrappers.
