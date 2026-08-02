# Pop!_OS Workstation Builder

**A declarative, zero-touch provisioning engine for Pop!_OS and System76 hardware built on strict 3-layer state governance.**

Most developer workstation setup scripts degrade into untamable complexity. Over months of installing AI frameworks, Node utilities, and system tools, your root filesystem swells with dozens of gigabytes of conflicting global packages (`npm -g`, `pip --user`, `bun -g`). When upgrading or refreshing a machine, reproducing that environment requires hours of hunting down unpinned dependencies and broken configurations.

This project fixes workstation bloat by separating machine provisioning into three distinct boundaries: immutable root system packages, encrypted user identity, and per-project isolated environments. By leveraging System76's native system daemons (`system76-power`, `kernelstub`) and APT package taxonomies, this collection turns a clean Pop!_OS installation into a fully configured AI engineering workstation in a single command.

---

## The 3-Layer Governance Architecture

To guarantee long-term reproducibility and eliminate root filesystem entropy, every configuration item in this ecosystem is strictly categorized into one of three execution layers:

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

### Why This Boundary Matters
- **Layer 1 (Ansible / Root)** owns only what requires superuser privileges and remains identical across all users of the operating system: system APT packages, container daemons, audio infrastructure (PipeWire/rtkit), and hardware drivers.
- **Layer 2 (`yadm` / User Home)** owns everything under `$HOME` that encodes your personal workflows, API keys, and shell preferences. Declarative manifests (`uv-tools.txt`, `npm-global.txt`) install developer CLI tools completely within user space.
- **Layer 3 (Project Repositories)** owns complex machine learning and web runtimes (e.g., PyTorch, CUDA bindings, Node frameworks). These never touch the OS or home directories; they are instantiated per-repository using modern fast resolvers like `uv` or `bun`.

> **Architectural Rule**: This Ansible collection will never execute root-level shell pipings (`curl | bash`), install global Node/Python packages, or touch user profile dotfiles directly. Its solely responsible for Layer 1 preparation and executing the Layer 2 handoff.

---

## Pop!_OS vs. RHEL: Native Engineering

If you are migrating from RHEL, Fedora, or traditional enterprise Ansible setups, notice how this repository diverges from standard Linux automation:

| Component | Traditional RHEL / Enterprise | This Pop!_OS Implementation | Engineering Rationale |
| :--- | :--- | :--- | :--- |
| **Bootloader API** | `grub2-mkconfig` / `grubby` | **`kernelstub` (systemd-boot)** | On UEFI systems, Pop!_OS ignores GRUB. Modifying EFIVARs and kernel arguments must be routed through System76's atomic `kernelstub` utility. |
| **GPU / AI Drivers** | RPM Fusion / External CUDA TOMLs | **`system76-driver-nvidia`** | System76 pre-packages and thoroughly validates proprietary NVIDIA graphics and AI runtimes against the custom Linux kernel. |
| **Power Profiles** | Custom bash scripts / `cpupower` | **`system76-power` daemons** | Native Rust daemons handle seamless switching between Hybrid, Discrete, and Compute GPU modes directly via terminal or panel applets. |
| **Real-Time Audio** | Manual limits & kernel recompilation | **PipeWire + `rtkit-daemon`** | Pre-wires professional low-latency JACK/PulseAudio bridging without risking unstable RT kernel locks. |

---

## Quickstart Guide

### Prerequisites
- A baseline installation of **Pop!_OS** (22.04 LTS, 24.04 LTS, or rolling upgrades), Ubuntu LTS, or compatible Debian derivative.
- Administrative (`sudo`) user access.
- An internet connection to fetch APT repositories and user dotfiles.

### Step 1: Bootstrap from Bare Metal
Open a fresh terminal session on your newly installed machine. Run the quickstart sequence to pull minimal toolchains (`git`, `ansible`, `zsh`, `yadm`) and prepare the workspace:

```bash
# Update local package indexes and install required provisioning engines
sudo apt update && sudo apt install -y git ansible

# Clone the workstation builder into your local setup directory
git clone https://github.com/b08x/pop_os-workstation-builder.git ~/.setup/pop_os-workstation-builder
cd ~/.setup/pop_os-workstation-builder

# Execute the bare-metal bootstrap validation
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml --ask-become-pass
```

### Step 2: Provision the Master Workstation
Once bootstrapped, kick off the comprehensive configuration engine. This applies kernel boot flags, installs daemons, optimizes APT, deploys container virtualization, and executes the `yadm` dotfiles handoff:

```bash
# Execute the full workstation orchestration playbook
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --ask-become-pass
```

### Step 3: Verification & Dry-Run
Because this collection is fully idempotent, you can re-run it at any time without side effects. To audit impending systemic changes before executing, utilize Ansible's dry-run diff mode:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --diff --check
```

---

## Repository Anatomy

```
pop_os-workstation-builder/
├── ansible.cfg                      # Optimized SSH pipelining & JSON fact caching
├── inventory/
│   └── hosts.ini                    # Direct localhost target with user customizations
├── playbooks/
│   ├── bootstrap.yml                # Entrypoint: Minimal system readiness and yadm installer
│   └── workstation.yml              # Master orchestration sequence across all system roles
├── roles/
│   ├── pop_base/                    # Timezone, APT non-interactive caching, core dumps disable
│   ├── pop_hardware/                # system76-driver daemons & kernelstub EFIVAR management
│   ├── pop_cosmic/                  # COSMIC DE / Pop!_Shell tiling, fonts, & rtkit audio
│   ├── podman_docker/               # Container engines (Docker/Podman) & hardware group ACLs
│   └── yadm_bootstrap/              # Layer 2 Handoff: clones user dotfiles and tool manifests
└── vars/
    └── pop_os_packages.yml          # Structured APT system taxonomy (AI, containers, media)
```

---

## Customizing Package Taxonomies

All system-level software installations are governed centrally by [vars/pop_os_packages.yml](file:///home/b08x/WorkspaceV3/Syncopated/pop_os-workstation-builder/vars/pop_os_packages.yml). To add system libraries or compiler toolchains to future provisions, append the desired deb package titles directly to the relevant structural categories:

```yaml
pop_os_packages:
  base_cli:
    - build-essential
    - jq
    - zsh
    # Add your custom system CLI tools here

  nvidia_ai_ml:
    - system76-driver-nvidia
    - nvidia-cuda-toolkit
    - python3-dev
```

---

## Engineering Roadmap

The future evolution of `pop_os-workstation-builder` is structured around enhancing autonomous validation, supporting System76's emerging Rust desktop architecture, and modularizing edge deployments.

### Milestone 1: COSMIC Desktop Transition (Q3 2026)
- [ ] **COSMIC Epoch Support**: Upgrade UI roles to officially configure System76's Rust-based COSMIC Desktop Environment as it reaches general production readiness, gracefully replacing legacy GNOME Pop!_Shell extensions.
- [ ] **Declarative Wayland Keybindings**: Integrate programmatic binding definitions for window tiling and workspace manipulation directly into COSMIC configuration schemas.

### Milestone 2: Automated Testing & Continuous Integration
- [ ] **GitHub Actions Infrastructure**: Implement continuous validation using linting (`ansible-lint`, `yamllint`) and automated testing against ephemeral Ubuntu/Debian container matrices.
- [ ] **Idempotency Assurance Engine**: Automated assertions ensuring back-to-back runs of `workstation.yml` produce zero changed states (`changed=0, unreachable=0, failed=0`).

### Milestone 3: Advanced AI Workstation Profiles
- [ ] **Modular GPU Acceleration Switching**: Add prompt-driven or inventory-controlled feature toggles between native NVIDIA CUDA profiles and modern OpenCL/AMD ROCm compute arrays.
- [ ] **Local LLM Server Primitives**: Create an optional `ollama_service` role capable of standing up locally hosted inference engines wrapped with GPU access rights in Layer 1.

### Milestone 4: Telemetry & Latency Profiling
- [ ] **Real-time Kernel Benchmarking**: Build optional diagnostic tasks to test pipewire latency and CPU core C-states under System76 audio scheduling rules.
- [ ] **Callback Analytics Plugin**: Adapt custom LLM-assisted structural callback summary plugins to analyze timing execution bottlenecks during local playbook provisioning.

---

## Contributing & Extending

This repository is built for clean fork-and-modify adaptability. When modifying roles or proposing architectural changes:

1. **Verify Layer Adherence**: Ask yourself: *Does this require root? Is it identical for all users?* If no, push the tool into your [Layer 2 yadm repository](https://github.com/b08x/dots).
2. **Preserve Documentation Integrity**: When editing tasks or variable trees, maintain inline comments explaining why a specific System76 daemon or systemd unit is required.
3. **Run Linting**: Verify valid syntax before committing:
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --syntax-check
   ```
