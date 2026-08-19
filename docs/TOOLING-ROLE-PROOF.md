# Proof: should Ansible own the installs?

**Opened:** 2026-08-11
**Status:** one ecosystem built and exercised. Scope decision deferred, by design.
**Reads with:** `ANSIBLE-AND-YADM.md`, `BACKLOG.md` items 2, 2a, 2b

The question was whether to move user-space installs out of
`~/.config/yadm/bootstrap.d` and into Ansible roles. Rather than argue it, the
call was to build one ecosystem and look at the result. This is the result.

---

## The shape that was built

**Ansible owns installs. The list is inventory data.**

`roles/tooling` reads `tooling_uv_tools` from `host_vars` and reconciles the
machine against it.

> **Revised mid-build.** The first version read the list from
> `~/.config/tooling/uv-tools.yml`, on the reasoning that a personal tool list
> in the collection would stop it being reusable by anyone else. That
> over-weighted a hypothetical second user of a collection with one workstation,
> one VM, and one human. `host_vars/gir.yml` is exactly where Ansible puts
> per-host specificity; someone forking writes their own. The change removed the
> role's only dependency on `$HOME`, which is why it now runs *before*
> `dotfiles` instead of after. See `ANSIBLE-AND-YADM.md`.

The role does not need root. `become_user` reaches `$HOME` perfectly well.

```yaml
# inventory/host_vars/gir.yml
tooling_uv_tools:
  - name: ansible-builder
    version: "3.1.1"
  - name: graphifyy
    version: "0.9.35"
  - name: example          # git-sourced entries are reconciled only when absent
    git: "https://github.com/b08x/example"
    rev: "v0.1.0"
  - name: omega13
    version: "2.3.0"
    with: ["extra-dep"]
```

---

## What was measured

Exercised against a real uv 0.12.3 with a two-tool list.

| Behaviour | Result |
|---|---|
| First run, empty machine | 2 declared, 2 reconciled, `changed=1` |
| **Second run, unchanged** | **2 declared, 0 reconciled, `changed=0`, 3.5 s** |
| One pin bumped `6.1` → `6.0` | 2 declared, **1** reconciled — only the bumped tool |
| `--check` on a converged host | clean, `changed=0`, no side effects |
| Empty list | reports and skips, naming the host_vars file to edit |

`ansible-lint --offline`: profile `production`, 0 failures.

These numbers were measured against the first build, which read the list from a
file. Only the *source* of the list changed afterwards; the reconciliation logic
that produces them is untouched.

---

## What it buys that bash did not

**1. Idempotency that is real rather than asserted.**
`01-setup-tools.sh` runs `uv tool install --upgrade` for every entry on every
pass. That is a network round trip per tool and a non-deterministic result. The
role reads `uv tool list` once, diffs it against the declared list, and touches
only the difference. The second-run number above — `changed=0` in 3.5 s — is the
"under five seconds with zero state mutations" bar from
`BACKLOG_YADM_REBUILD.md`'s definition of done, which the bash version has
never met.

**2. The manifest format problem disappears.**
Item 2a needed a format that could hold a PyPI pin, a git ref, and a
URL+checksum, and was heading toward inventing a line syntax with source
prefixes. Inventory YAML plus Ansible's existing modules is that work already
done — and `meta/argument_specs.yml` validates the entries, which a text file
never would have.

**3. uv itself gets pinned.**
It currently arrives from Astral's `install.sh` at floating latest, which makes
the foundation of the entire Python strategy the least pinned thing in it. The
role installs a named release with `get_url` and a `sha256`. This matters more
than it looks: available Python downloads are frozen per uv release, so the uv
pin also decides which CPythons uv can install.

**4. `UV_TORCH_BACKEND` applies everywhere, structurally.**
Set once in the role environment rather than hoped for in a shell profile. The
5 GB of `cu13` wheels that landed in a CLI tool's venv on `popvm` cannot recur
through this path. Confirmed that the variable changes uv's behaviour: unset,
`torch==2.13.0` resolves 16 nvidia/triton wheels from PyPI; set to `cpu`, uv
switches to `download.pytorch.org/whl/cpu`.

**5. The seam mostly stopped existing.**
`ANSIBLE-AND-YADM.md` named the untested Layer 1 → Layer 2 handoff as the
architecture's real weakness, and the first build answered it with a
`tooling_require_manifests` assertion. Moving the list to `host_vars` was
better: the role no longer reads `$HOME` at all, so there is nothing to assert.
The only remaining crossing is the yadm clone, which `dotfiles` already handles
explicitly. Dissolving a seam beats testing one.

---

## What it does not solve

Worth being explicit, because the case for this is strong enough that its
limits are easy to skip past.

- **The clone ordering survives.** Ansible still cannot fetch the yadm repo
  before the SSH key exists. Moving installs into Ansible shrinks the bootstrap
  sequence; it does not dissolve it.
- **yadm is not going anywhere.** `encrypt` remains the only good answer for
  the fourteen Hermes profiles, and the shell, agent skills and app configs are
  authored content no package manager produces.
- **Ansible must exist before it can install anything.** `ansible-builder` and
  `ansible-navigator` are currently uv tools, i.e. installed by the thing that
  needs them. ansible-core has to come from apt.
- **`--check` cannot predict a first install.** On an unconverged host, check
  mode reports what would be reconciled but cannot resolve versions without
  network access to the index.
- **Editing a tool version is now a collection commit**, not `yadm edit`. That
  is arguably right — the collection is the thing that rebuilds the machine —
  but it is a change in where the muscle memory goes.

---

## Before extending this

Each remaining ecosystem has a distinct failure mode. They are not four copies
of the same task.

| Ecosystem | The hard part |
|---|---|
| cargo | `cargo install --list` is parseable, but two entries build from local paths and one of those (`zeroclaw`, from a `/tmp` bootstrap dir) has no reproducible source at all. |
| npm | `@tobilu/qmd` is a fork requiring a build; `better-sqlite3`, `node-llama-cpp` and four tree-sitter grammars compile on install and need Node ≥22 in Layer 1. Four current globals resolve from nowhere. |
| binaries | `codebase-memory-mcp` is `get_url` + `checksum` + `unarchive` — genuinely trivial, and the best second candidate. |
| flatpak | Already works in `02-flatpaks.sh` and is honestly user-scope. Lowest value to move, and moving it costs the gum TUI. |

**Suggested next step:** do `binaries` second. It is small, it has no build
step, and it proves the URL+checksum shape that the line-format debate was
stuck on. If that also comes out clean, migrate cargo and npm and let
`bootstrap.d` keep flatpaks and permissions hardening.

**Do not migrate everything at once.** The bash pipeline works today. The only
thing that would make this worse than what exists is a half-finished migration
where some tools are declared in one place and some in another.
