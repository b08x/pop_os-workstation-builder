# Agent Handbook: `b08x.workstation`

An Ansible collection for personal workstation management — turning a clean Pop!_OS install into a reproducible AI-engineering environment. Built and maintained with LLM agent assistance.

---

## What This Repository Is

An exercise in systems engineering applied to a single human's machines. The goal is **reproducibility without root filesystem entropy**: instead of accumulating a decade of `curl | bash` and global pip installs, every configuration decision is encoded as declarative YAML and applied deterministically.

| Layer | Owner | Scope |
|-------|-------|-------|
| **Layer 1** | This Ansible collection | Root/system-wide: APT, System76 daemons, kernelstub, container infrastructure |
| **Layer 2** | `yadm` dotfiles repo | `$HOME`: shell, editor, agent configs, SSH/GPG, user-scope tool manifests |
| **Layer 3** | Per-project `uv`/`venv` | Repo-local ephemeral runtimes: PyTorch, Node, etc. |

**The single architectural rule**: if it requires root and is identical for all users of the OS, it belongs in this collection. If it lives in `$HOME` or is user-specific, it belongs in yadm. If it is project-local, it belongs in that project's environment.

---

## Key Commands

### Running the playbooks

```bash
# First: get a bare machine to a usable state (SSH, python3, yadm)
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml --ask-become-pass

# Full provision (reboot detection, yadm handoff, everything)
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --ask-become-pass

# Dry-run with diff preview
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --diff --check

# Run a single role by tag
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --tags nvidia
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --tags cdi

# Syntax check (fast, no connection required)
ansible-playbook -i inventory/hosts.ini playbooks/workstation.yml --syntax-check
```

### Linting

```bash
ansible-lint                    # profile=production, offline
ansible-lint playbooks/*.yml   # specific file
yamllint                        # YAML syntax only
```

### Documentation

```bash
ansible-doc -t role -r roles b08x.workstation.hardware   # print argument spec for a role
```

### Updating uv

```bash
# Get the sha256 for a new uv release
curl -sSL https://github.com/astral-sh/uv/releases/download/0.12.3/uv-x86_64-unknown-linux-gnu.tar.gz.sha256
```

---

## Repository Structure

```
pop_os-workstation-builder/          # collection root (b08x.workstation)
├── galaxy.yml                      # collection metadata
├── meta/runtime.yml                # ansible version requirement
├── ansible.cfg                     # pipelining, JSON fact caching
├── inventory/
│   ├── hosts.ini                   # target hosts
│   ├── group_vars/workstations.yml  # shared defaults (overrides go here)
│   └── host_vars/<host>.yml        # per-machine config (tool list, etc.)
├── playbooks/
│   ├── bootstrap.yml               # minimum viable first-run (SSH, python3, yadm)
│   └── workstation.yml             # full Layer 1 provision
└── roles/
    ├── base/       # timezone, coredump policy, APT tuning, zram, CLI toolchain
    ├── hardware/   # System76 daemons, NVIDIA driver, CDI spec, kernelstub, graphics mode
    ├── desktop/    # fonts, PipeWire, real-time audio limits (rtkit)
    ├── containers/ # Podman (default), Docker (opt-in), group membership, GPU verification
    ├── dotfiles/   # yadm install, clone, bootstrap handoff
    └── tooling/    # uv and Python CLI tool installs (proof-of-concept; uv only)
```

Each role is self-contained: its own `defaults/`, `meta/argument_specs.yml`, `handlers/`, and `tasks/`. No role reads a variable file outside its own directory.

---

## Playbook Execution Order

`workstation.yml` runs roles in this order and relies on it:

1. **`base`** — must run first; sets the foundation other roles assume (APT config, timezone, zram)
2. **`hardware`** — installs System76 packages and NVIDIA driver; generates CDI spec for GPU containers; runs `system76-power graphics`; manages kernelstub
3. **`desktop`** — fonts, PipeWire, rtkit real-time limits
4. **`containers`** — Podman/Docker; grants group membership; verifies CDI spec exists
5. **`tooling`** — installs uv and Python CLI tools; **reads from `host_vars`, not from `$HOME`**, so it works on first run before yadm
6. **`dotfiles`** — installs yadm, clones the dotfiles repo, hands off to Layer 2

The `apt_optional.yml` include lets hardware roles install packages that may not be present on all hosts without failing.

---

## Important Gotchas

### Pop!_OS Is Not RHEL/Fedora

- **Bootloader**: Pop!_OS uses `systemd-boot`, not GRUB. Kernel arguments go through `kernelstub`, not `grubby` or `grub2-mkconfig`. The role detects `kernelstub`'s presence and warns if it's missing.
- **GPU drivers**: System76 packages and validates the NVIDIA driver. Do **not** add `nvidia-driver-*` APT packages alongside `system76-driver-nvidia` — two competing driver sources, and which wins is resolution-order luck.
- **Power profiles**: `system76-power` conflicts with `power-profiles-daemon` (GNOME's default). The hardware role masks it automatically. If `com.system76.PowerDaemon.service` won't start, check that `power-profiles-daemon.service` is masked.
- **CUDA on the host**: **Default is OFF**. The driver ships a basic CUDA runtime already (`libnvidia-compute-*`). A host toolkit layered under user-space installs duplicates it (~21 GB observed). CUDA workloads belong in containers with `nvidia-container-toolkit`.

### CDI Spec Goes Stale on Driver Upgrade

`nvidia-container-toolkit` installation is necessary but not sufficient. The CDI spec (`/etc/cdi/nvidia.yaml`) records driver library paths, so it breaks silently after driver upgrades. The role enables `nvidia-cdi-refresh.path` where available; otherwise it warns and instructs you to re-run with `--tags cdi` after any driver change.

### `uv` Version Pin Is Structural

The uv pin is not just a preference — available Python downloads are frozen per uv release, so the uv pin **determines which CPythons** `uv` can install. Bump deliberately and update the checksum.

### `UV_TORCH_BACKEND: auto`

Set on every `uv tool install` call. Without it, any tool with a torch dependency pulls the full CUDA build into its venv — observed live as ~5 GB of cu13 wheels on a guest with no GPU. `auto` queries the installed driver and picks the matching PyTorch index, falling back to CPU-only wheels.

### `tooling` Has No Dependency on `dotfiles`

The tooling role reads `tooling_uv_tools` from `inventory/host_vars/`, **not** from `~/.config/tooling/` or anywhere in `$HOME`. This was a deliberate architectural correction — it means tooling runs successfully on first provision before yadm has been cloned.

### `changed_when` on Idempotency-Sensitive Tasks

Several tasks use `changed_when: true` unconditionally — this is intentional. The task only receives items already determined to be out of sync by a comparison step upstream. Setting `changed_when: false` on those would produce false negatives. The idempotency lives in the comparison, not the `changed_when` expression.

### Ansible `apt` Module Does Not Return `rc`

The `apt_optional.yml` pattern queries `apt-cache policy` before installing because the old approach used `result.rc` on the `apt` module — which does not return `rc`. The guard never worked as written.

---

## Variable Taxonomy

| Variable prefix | Where it's defined | What it controls |
|-----------------|-------------------|------------------|
| `workstation_user` | `group_vars/workstations.yml` | Single source of truth for the human's username |
| `base_*` | `roles/base/defaults/main.yml` | Timezone, coredumps, APT tuning, packages |
| `hardware_*` | `roles/hardware/defaults/main.yml` | System76, NVIDIA, CDI, kernelstub, graphics mode |
| `containers_*` | `roles/containers/defaults/main.yml` | Podman/Docker, groups, GPU verification |
| `desktop_*` | `roles/desktop/defaults/main.yml` | Fonts, audio, rtkit |
| `dotfiles_*` | `roles/dotfiles/defaults/main.yml` | yadm, repo URL, bootstrap flag |
| `tooling_*` | `roles/tooling/defaults/main.yml` + `host_vars/*.yml` | uv version, Python tool list |
| `bootstrap_*` | `playbooks/bootstrap.yml` (inline vars) | Bootstrap package set only |

Override in `inventory/group_vars/workstations.yml` for shared settings, or `inventory/host_vars/<host>.yml` for per-machine overrides. **Do not modify role defaults** — they are the documented interface.

---

## Adding a New Role

1. Create `roles/<name>/{defaults/main.yml,meta/main.yml,meta/argument_specs.yml,tasks/main.yml,handlers/main.yml}`
2. Add to `playbooks/workstation.yml` under `roles:` with appropriate tags
3. Add role documentation to `meta/argument_specs.yml` — this is what `ansible-doc` surfaces
4. If the role installs optional packages, use the `apt_optional.yml` include pattern from `hardware/`
5. Add `become: true` only where root is actually required; prefer `become_user` for `$HOME` access
6. Test idempotency: run twice, verify `changed=0` on the second pass

---

## Linting Rules

- **Profile**: `production` (see `.ansible-lint`)
- **Excluded paths**: `.ansible/`, `.github/`, `fact_cache/`, `docs/`
- **`role-name` skip_list entry**: roles are namespaced by the collection (`b08x.workstation.<role>`), not by `b08x.` prefix, so the lint rule is disabled

---

## Idempotency Checklist

Before considering a change done, verify:
- [ ] Second run produces `changed=0` on an already-provisioned host
- [ ] `--check` on an unconverged host does not cause side effects
- [ ] The role tolerates a fresh install (all packages absent) without errors
- [ ] Optional packages that don't exist on this host are skipped, not failed on
- [ ] A reboot mid-run (graphics mode, kernel args) is handled gracefully
