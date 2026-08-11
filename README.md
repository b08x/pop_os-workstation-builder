# Pop!_OS Workstation Builder — `b08x.workstation`

**An Ansible collection for configuring a fresh Pop!_OS installation, built as an exercise in agentic coding workflows.**

This project was assembled using agentic coding tools — [Hermes Agent](https://hermes-agent.nousresearch.com), Claude Code, [Agy](https://github.com/nicobailey/agy), [Crush](https://github.com/nicobailey/crush), and [OpenCode](https://github.com/nicobailey/opencode) — to explore how AI-assisted development can accelerate infrastructure-as-code authoring. The result is a working collection of Ansible roles that turns a clean Pop!_OS installation into a configured engineering workstation in a single command.

The repository itself is the artifact. The process of building it — iterating on role structure, debugging idempotency, refining variable taxonomies, and reviewing best practices through an AI agent — is the point.

---

## What This Repository Does

Most developer workstation setup scripts degrade into untamable complexity. Over months of installing AI frameworks, Node utilities, and system tools, your root filesystem swells with dozens of gigabytes of conflicting global packages. When upgrading or refreshing a machine, reproducing that environment requires hours of hunting down unpinned dependencies and broken configurations.

This project fixes workstation bloat by separating machine provisioning into three distinct boundaries: immutable root system packages, encrypted user identity, and per-project isolated environments. By leveraging System76's native system daemons (`system76-power`, `kernelstub`) and APT package taxonomies, this collection turns a clean Pop!_OS installation into a fully configured AI engineering workstation.

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

> **Architectural Rule**: This Ansible collection will never execute root-level shell pipings (`curl | bash`), install global Node/Python packages, or touch user profile dotfiles directly. It is solely responsible for Layer 1 preparation and executing the Layer 2 handoff.

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
pop_os-workstation-builder/            # collection root: b08x.workstation
├── galaxy.yml                         # collection metadata and dependencies
├── meta/runtime.yml                   # requires_ansible, action groups
├── ansible.cfg                        # SSH pipelining, JSON fact caching
├── changelogs/changelog.yaml
├── inventory/
│   ├── hosts.ini
│   ├── group_vars/workstations.yml    # workstation_user and deliberate overrides
│   └── host_vars/popvm.yml            # test-VM overrides
├── playbooks/
│   ├── bootstrap.yml                  # minimum viable state on a fresh install
│   └── workstation.yml                # full Layer 1 provision
└── roles/
    ├── base/                          # timezone, APT tuning, core dumps, CLI toolchain
    ├── hardware/                      # System76 daemons, NVIDIA, graphics mode, kernelstub
    ├── desktop/                       # fonts, PipeWire, real-time audio limits
    ├── containers/                    # Podman by default, Docker opt-in
    └── dotfiles/                      # yadm install and the Layer 2 handoff
```

Every role carries its own `defaults/`, `meta/main.yml`, `meta/argument_specs.yml`,
`handlers/` and `tasks/`. No role reads a variable file outside its own directory,
so any one of them can be lifted out without dragging the rest along.

---

## Customizing Package Sets

There is no central `vars/` file. Each role declares the packages it owns in its
own `defaults/main.yml`, and `meta/argument_specs.yml` documents every variable
with a type and a default. To see what a role accepts:

```bash
ansible-doc -t role -r roles b08x.workstation.hardware
```

Override in `inventory/group_vars/workstations.yml`, not in the role:

```yaml
base_packages: "{{ b08x_base_default_packages + ['direnv', 'ripgrep'] }}"
hardware_graphics_mode: compute      # integrated | nvidia | hybrid | compute
containers_install_docker: true      # adds a root daemon and a second storage pool
```

### Two defaults that are deliberate, not accidental

**Host CUDA is off.** `hardware_install_host_cuda` defaults to `false`. System76
documents that basic CUDA runtime already ships with the driver, in the
`libnvidia-compute-*` packages — check the ceiling with `nvidia-smi`. The
prior audit of this workstation measured ~21 GB of overlapping CUDA runtime,
caused by layering a host toolkit under user-space installs of the same
libraries. Use an
`nvidia/cuda` container image with `nvidia-container-toolkit` instead.

**Docker is off.** `containers_install_docker` defaults to `false`. Podman covers
the same ground without a root daemon or a second storage pool, and the `docker`
group is root-equivalent, so it is granted only when Docker is actually
installed.

---

## How This Was Built: Agentic Coding Workflow

This repository was developed collaboratively with AI coding agents. The workflow looked like this:

1. **Scaffolding**: The initial role structure, inventory, and playbook skeleton were generated by an agent given a description of the target system (Pop!_OS + System76 hardware + AI/ML workstation use case).

2. **Iterative Refinement**: Roles were debugged and improved through agent-assisted review cycles — checking idempotency patterns, verifying module usage against Ansible best practices, and restructuring tasks for clarity.

3. **Best-Practice Audit**: The agent compared the project against RHCE study guide frameworks and Tim Appnel's role design principles, identifying gaps (missing `defaults/`, broad `ignore_errors`, incomplete role scaffolding) and proposing fixes.

4. **Documentation**: The README, inline comments, and variable taxonomy descriptions were written and refined through the same agentic workflow.

The tools used:

| Tool | Role in This Project |
| :--- | :--- |
| **Hermes Agent** | Primary orchestrator — role authoring, best-practice review, documentation generation |
| **Claude Code** | Deep reasoning on Ansible module selection, idempotency verification |
| **Agy** | Task decomposition and parallel role development |
| **Crush** | Quick edits, YAML formatting, syntax validation |
| **OpenCode** | Exploration of System76-specific tooling APIs (kernelstub, system76-power) |

---

## Engineering Roadmap

The future evolution of `pop_os-workstation-builder` is structured around enhancing autonomous validation, supporting System76's emerging Rust desktop architecture, and mitigating systemic risks discovered during forensic machine audits.

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

### Milestone 5: Out-of-Tree (`@commandline`) Package Preservation Engine

- [ ] **Debian Package Cache Archival**: Build an automated preservation task (`roles/deb_archive`) that detects loose `.deb` packages or AppImages installed outside standard APT repositories (e.g., downloaded build artifacts for tools like `hermes-desktop`, `Multica`, and `trackboi`).
- [ ] **Automated Rebuild Manifest Generation**: Emit machine-readable system snapshots capturing local hardware driver verifiers and package origins before performing workstation refreshes.

### Milestone 6: Pre-Refresh Forensic Audit Suite

- [ ] **Git Work-at-Risk Detection Playbook**: Develop an operational audit playbook (`playbooks/audit-refresh.yml`) that scans user workspaces (`WorkspaceV3`, `StudioV2`) prior to wiping, alerting on dirty working trees, uncommitted stashes, and repositories lacking remotes.
- [ ] **Automated Backup Exclusions Generator**: Dynamically compile exclusion rules for tools like `deja-dup` or `restic` to bypass ~110 GB of regenerable cache directories (`node_modules`, `.venv`, `.cache`, `.hermes/state-snapshots`).

### Milestone 7: Containerized AI/ML Runtime Harmonization

- [ ] **Container-First ML Pipeline Standard**: Eliminate system library collisions and multi-gigabyte storage duplication (e.g., overlapping CUDA bindings across host systems and Python venvs) by routing PyTorch, spaCy large NLP models, and `onnxruntime` workloads strictly through Podman/Docker containers utilizing `nvidia-container-toolkit`.

### Milestone 8: Mandatory Access Control (AppArmor Harmonization)

- [ ] **AppArmor Real-Time Profiling**: Replace permissive MAC fallbacks with validated AppArmor profiles in `roles/pop_base`, ensuring container audio UNIX domain sockets (`pipewire-0`) and AI IPC sockets operate securely without silent kernel permission denials.

---

## Contributing & Extending

This repository is built for clean fork-and-modify adaptability. When modifying roles or proposing architectural changes:

1. **Verify Layer Adherence**: Ask yourself: *Does this require root? Is it identical for all users?* If no, push the tool into your [Layer 2 yadm repository](https://github.com/b08x/dots).
2. **Preserve Documentation Integrity**: When editing tasks or variable trees, maintain inline comments explaining why a specific System76 daemon or systemd unit is required.
3. **Run Linting**: Verify valid syntax before committing:
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --syntax-check
   ```
