# Backlog — `b08x.workstation`

**Opened:** 2026-08-10
**Context:** Layer 1 is built and verified. Everything below is Layer 2 and Layer 3 —
the parts the collection deliberately does *not* own, which still need a plan before
`gir` gets wiped.

Inventories captured while `gir` was still Fedora 43 live in
`../workstation-forensics/manifests/`. Those lists stop existing after the wipe,
so triage against the snapshot rather than against memory.

**Updated 2026-08-11:** item 1 decided (asdf, Ruby only), item 2a added (patched
agent tooling — `qmd`, `graphify`, `codebase-memory-mcp`), item 2b added and the
CDI gap **fixed in the roles**, item 2c added (`tooling` role built — installs
move to Ansible), item 3 resolved (SaveDesktop owns Flatpak appdata), item 4a
added (containerized `hermes` role).

**The scope of yadm changed today**, which is the thing to read first if you're
returning to this cold. `ANSIBLE-AND-YADM.md` now governs it by enumeration
rather than by rule:

> yadm owns (1) what you authored, (2) what a tool reads from a fixed `$HOME`
> path, (3) what needs `encrypt`. **Ansible owns every install**, including
> installs into `$HOME`.

The earlier "audience" rule sorted correctly but had to be argued every time.
It's gone. Layer 3 templates live in `LAYER3-PYPROJECT.md`.

---

## Where things stand

| | Status |
|---|---|
| `b08x.workstation` collection | Layer 1 done, lint clean, idempotent on `popvm` |
| System76 path (vendor pkgs, ppd masking, graphics, firmware group) | written, **unexercised** — only testable on `gir` post-install |
| `gir` | still Fedora 43, 362 G used of 475 G (78 %) |
| Backups | restic, 218 snapshots, latest 2026-08-10 17:57, 157 GiB |
| `development` branch | 11 ahead of `origin`, **unpushed** |

---

## 1. asdf and Ruby 4 — DECIDED 2026-08-11

**Decision: asdf stays, for Ruby only.** `uv` keeps Python, cargo/npm keep their own
binaries, and asdf's scope narrows to the one language that actually needs a version
manager. A single-language version manager for one language is the accepted outcome.

**The finding that forced it:** asdf is declared but not provisioned.
`~/.tool-versions` asks for `ruby 4.0.1` and `uv 0.9.28`; asdf 0.19.0 (the Go rewrite)
is installed at `/usr/bin/asdf` with shims at `/opt/asdf/shims`, but **zero plugins are
installed and zero rubies are built**. Meanwhile `/usr/bin/ruby` is 3.4.10 from the
distro — so today every `ruby` invocation silently resolves to 3.4.10 while the
declaration says 4.0.1. The current asdf on `gir` is, in effect, borked: correctly
installed, entirely unpopulated.

### What this means concretely

| Item | Layer | Owner |
|---|---|---|
| `asdf` binary, `/opt/asdf` shim dir, `ASDF_DATA_DIR` in `/etc/environment` | 1 | new `asdf` role |
| `asdf plugin add ruby`, `asdf install ruby 4.0.1` | 2 | `bootstrap.d/04-asdf-ruby.sh` |
| `~/.tool-versions`, `~/.default-gems` | 2 | yadm (already tracked) |
| Gems | 3 | project `Gemfile.lock` |

**Drop the `uv 0.9.28` line from `.tool-versions`.** asdf is Ruby-only now; `uv`
installs itself in `01-setup-tools.sh` and pinning it in two places is how they drift.

### Open, but no longer blocking

- Ruby 4.0.1 compatibility against `sfl-engine`, `ruby-dev-plugin`, `rubygemdb`,
  `RubyLLM-SFL-RAG`. If one of them can't move, pin *that project* to 3.4 via a
  repo-local `.tool-versions` — which is exactly what Layer 3 is for. The global
  declaration doesn't have to be hostage to the laggard.
- asdf 0.19 is the Go rewrite; its plugin/shim model differs from the old shell
  version. `ruby-build` still needs the usual apt build deps (`libssl-dev`,
  `libyaml-dev`, `libreadline-dev`, `zlib1g-dev`, `libffi-dev`, `libgmp-dev`,
  `build-essential`) — those go in the `base` role, not the bootstrap script.

### Work

- [ ] `roles/asdf/` — apt install, `/opt/asdf` shim dir, `ASDF_DATA_DIR`, PATH shim
      in `/etc/profile.d/`. Match the conventions of the existing five roles
      (defaults, `meta/argument_specs.yml`, handlers).
- [ ] Ruby build deps → `base_packages`.
- [ ] `bootstrap.d/04-asdf-ruby.sh` — plugin add, install from `.tool-versions`,
      `gem install` from `.default-gems`. Idempotent, no sudo.
- [ ] Prune `uv` from `.tool-versions`.

---

## 2. Terminal utilities

Three parallel package managers currently hold CLI tools, none declared anywhere:

| Source | Count | Snapshot |
|---|---:|---|
| `cargo install` | 16 | `toolchain-userspace.txt` |
| `uv tool` | 11 | `toolchain-userspace.txt` |
| `npm -g` | 26 | `toolchain-userspace.txt` |

Notes from the snapshot:

- **cargo:** `bottom choose csvlens eza git-cliff gping just just-lsp llmfit
  markdown-oxide resvg ripgrep_all sd weathr` plus two local-path builds
  (`whis-cli` from `~/Workspace/source/whis`, `zeroclaw` from a `/tmp` bootstrap dir).
  The `/tmp` one cannot be reproduced — its source is gone. Decide whether zeroclaw
  matters before the wipe.
- **uv tool:** `ansible-builder ansible-navigator devstart ~~docs2db~~ graphifyy
  linux-mcp-server mistral-vibe notebooklm-py omega13 rubygemdb seishun`. Several are
  your own projects; those need their repos reachable before reinstall works.
  **`docs2db` is dropped (2026-08-11)** — it depends on torch and was the tool that
  pulled 5 GB of CUDA wheels onto `popvm`. See item 2b. Also remove it from
  `TASK-202` in `~/.config/yadm/bootstrap.d/BACKLOG_YADM_REBUILD.md`.
- **npm -g:** includes two `-> ./...` symlinks into `~/WorkspaceV3/code-insights`,
  and four entries with empty versions (`@open-gitagent/gapman`, `codeburn`,
  `hermes-paperclip-adapter`, `code-insights-workspace`) — local installs that will
  not resolve from a registry.

Work: turn each list into structured entries in `inventory/host_vars/gir.yml`,
consumed by the `tooling` role (item 2c). Some of these are also available as apt
packages on noble (`bottom`, `eza`, `just`, `sd`, `ripgrep`) — prefer apt where
the version is current, since `base_packages` is cheaper to maintain than a
per-tool pin.

**Superseded by item 2c.** These lists are no longer headed for
`~/.config/tooling/`. A version-pinned package list is a description of installs,
and installs are Ansible's — yadm keeps authored content. The `uv` list has
already moved; cargo, npm and binaries follow when their ecosystems are built.

**Layer:** lists → `host_vars`, Layer 1. Anything moved to apt → `base_packages`.

---

## 2c. Installs move to Ansible — PROOF BUILT 2026-08-11

**Shape: Ansible owns installs. The tool list is inventory data.**
`roles/tooling` reads `tooling_uv_tools` from `inventory/host_vars/gir.yml` and
reconciles the machine against it. Uses `become_user`; needs no root.

> **Revised mid-build.** The list first lived in `~/.config/tooling/`, on the
> reasoning that personal tooling in the collection would stop it being reusable
> by anyone else. That over-weighted a hypothetical second user of a collection
> with one workstation, one VM and one human. `host_vars` is exactly where
> Ansible puts per-host specificity. The change removed the role's only read of
> `$HOME`, which is why it now runs **before** `dotfiles` rather than after —
> and why `tooling_require_manifests` no longer exists.

Built and exercised for **uv only**, deliberately. Measured:

| | |
|---|---|
| First run, empty | 2 declared, 2 reconciled, `changed=1` |
| **Second run** | **0 reconciled, `changed=0`, 3.5 s** |
| One pin bumped | exactly 1 reconciled |
| `--check`, converged | clean |
| `ansible-lint --offline` | `production`, 0 failures |

That second-run number is the "under five seconds, zero mutations" bar from
`BACKLOG_YADM_REBUILD.md` — which `01-setup-tools.sh` has never met, because it
runs `uv tool install --upgrade` on every entry every pass.

Three things it fixes beyond tidiness:

- **The item 2a manifest-format problem disappears.** No line syntax with
  source prefixes to invent; inventory YAML plus existing modules is that work
  done — and `argument_specs` validates the entries, which a text file wouldn't.
- **uv gets pinned**, with `get_url` + `sha256`, instead of `install.sh` at
  floating latest. Since available Python downloads are frozen per uv release,
  the uv pin also decides which CPythons uv can install.
- **The seam largely dissolved.** `ANSIBLE-AND-YADM.md` called the untested
  Layer 1 → Layer 2 handoff the architecture's real weakness. With the list in
  `host_vars` the role reads nothing from `$HOME`, so there is nothing to
  assert. The only crossing left is the yadm clone, which `dotfiles` handles.

What it does not fix: the clone ordering survives, yadm stays regardless for
`encrypt` and authored content, and ansible-core has to come from apt since
`ansible-builder`/`-navigator` are themselves uv tools.

Full write-up, including per-ecosystem hazards: **`TOOLING-ROLE-PROOF.md`**.

- [ ] **Get the uv checksum** — `tooling_uv_checksum` is empty, so the download
      is currently unverified (the role warns rather than failing).
      `curl -sSL <base>/0.12.3/uv-x86_64-unknown-linux-gnu.tar.gz.sha256`
- [x] ~~Write the real tool list~~ — `inventory/host_vars/gir.yml` now carries
      the ten uv tools from the 2026-08-10 snapshot, minus `docs2db`.
- [ ] Run against `popvm` end to end — the proof ran against a synthetic
      two-tool list, not yours.
- [ ] **Do `binaries` second, not cargo or npm.** `codebase-memory-mcp` is
      `get_url` + `checksum` + `unarchive` with no build step, and it proves the
      URL+checksum shape the format debate was stuck on.
- [ ] Then decide scope. Do not half-migrate — tools declared in two places is
      worse than the bash pipeline that works today.

---

## 2a. Patched tooling — `codebase-memory-mcp`, `qmd`, `graphify`

**New 2026-08-11.** Three tools, three package ecosystems, one shared problem:
**two of the three carry local modifications, which is why "just update it" has
never happened.** A version-pinning strategy that doesn't account for the patches
would quietly revert them on first run. Handle the patches first; the manifest
format falls out of that.

| Tool | Source | Installed | Latest | Local change |
|---|---|---:|---:|---|
| `codebase-memory-mcp` | GitHub release, static binary | **not installed** | — | none |
| `qmd` | `@tobilu/qmd` (npm) | 2.1.0 via `bun -g` | 2.5.3 | **fork** — Ruby AST support |
| `graphify` | `graphifyy` (PyPI) | 0.9.35 via `uv tool` | 0.9.39 | **patched** — OpenRouter base URL |

### graphify — the patch is obsolete; delete it

The edit is in `~/.local/lib/python3.14/site-packages/graphify/llm.py`, pointing
the OpenAI base URL at OpenRouter. Three separate problems with that, and one
clean fix:

1. **Upstream already supports this.** `graphifyy` 0.9.39 `llm.py:153` reads
   `os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")`. There is
   also a sanctioned custom-provider mechanism at **`~/.graphify/providers.json`**
   (global scope is trusted; project-local requires `GRAPHIFY_ALLOW_LOCAL_PROVIDERS=1`,
   because a provider config is a corpus-exfiltration vector). Whenever the patch
   was written it was necessary; it isn't now.
2. **You patched the wrong copy.** There are two graphifys on `gir`:
   `graphifyy 0.9.35` as a `uv tool` (in `~/.local/share/uv/tools/`) and
   `graphifyy==0.8.44` in the `pip --user` tree. The path above is the **0.8.44
   one**. Which binary actually runs depends on PATH order — this is the
   duplicate-install problem from `ANSIBLE-YADM-SPLIT.md` showing up with teeth.
3. **That path cannot survive the wipe.** `python3.14` doesn't exist on noble
   (3.12), and `PIP_REQUIRE_VIRTUALENV=true` makes the whole `pip --user` tree
   unreachable by design.

**Fix:** drop the patch, keep `graphifyy` as a plain `uv tool`, and move the
OpenRouter routing into `~/.graphify/providers.json` — a Layer 2 config file,
yadm-tracked, added to `~/.config/yadm/encrypt` if it carries the key inline
(better: key in `~/.config/tooling/secrets.env`, already in the encrypt list).
Purge the `pip --user` copy at wipe time and don't reinstate it.

- [ ] Diff the local `llm.py` against upstream 0.9.39 — confirm the base-URL
      change is the *only* delta before deleting it.
- [ ] Write `~/.graphify/providers.json`, track it, verify a run routes to OpenRouter.

### qmd — the fork is real and stays

`b08x/qmd`, branch `feature/ruby_tree_sitter`, last touched 2026-05-22. Upstream
has moved 2.1.0 → 2.5.3 since. Decision: **keep the fork, rebase and build.**

What that costs, concretely:

- Node **≥ 22**. Currently installed via `bun -g`; upstream `engines` says node.
- Native deps that compile on install: `better-sqlite3`, `node-llama-cpp`, and
  four tree-sitter grammars (go, javascript, python, rust — Ruby is your addition).
  `sqlite-vec` ships prebuilt platform packages. This needs `build-essential`,
  `python3`, and `node-gyp` present — **Layer 1, `base_packages`.**
- The entry is a **git ref**, not a version string. Item 2c's structured
  `host_vars` shape already expresses this (`git:` + `rev:`); the flat
  `npm-global.txt` never could.
- [ ] Rebase `feature/ruby_tree_sitter` onto upstream 2.5.3. Four minors of drift
      across a package that added `node-llama-cpp` — expect real conflicts.
- [ ] Check whether Ruby tree-sitter landed upstream in the interim. If it did,
      the fork's reason is gone and this becomes a delete.

### codebase-memory-mcp — the easy one

Not installed anywhere yet. Static binary, no runtime deps. Installer is
`curl -fsSL .../install.sh | bash`, but unusually well-behaved for that genre:
wrapped in `main()` so a truncated download can't half-execute, mandatory
SHA-256 verification against the release's `checksums.txt`, HTTPS enforced
through redirects. Linux gets a fully-static `-portable` build.

Pin the release tag rather than tracking `latest`, and fetch the tarball +
`checksums.txt` directly — the binary has its own `update` subcommand and drops
a copy of `install.sh` beside itself, neither of which you want deciding when
your machine changes.

- [ ] Pin a tag in `host_vars` with URL + expected sha256. **This is the second
      ecosystem to build** (item 2c) — `get_url` + `checksum` + `unarchive`, no
      build step, and it proves the URL+checksum shape.

### Agent config — tools own it, yadm ignores it

**Decision: let each installer write its own registration.** All three write into
agent config directories: `codebase-memory-mcp install` configures agents unless
`--skip-config`; graphify writes `SKILL.md` + `.graphify_version` into
`.claude/`, `.vibe/`, `.hermes/` and a dozen other hosts; qmd exposes `qmd mcp`
and gets registered per-host.

Consequence to accept knowingly: **agent MCP config stops being reproducible from
the dotfiles repo.** In exchange, nothing has to be re-derived every time a tool
changes its own invocation. Add to `.yadmignore`:

```text
# Tool-generated agent skill/MCP registrations — owned by the installers
.vibe/skills/*/
.claude/skills/graphify/
.graphify_version
.graphify/cache/
```

Note `.vibe/skills/graphify/SKILL.md` and `.graphify_version` are **currently
tracked** — they need `git rm --cached` via yadm, not just an ignore rule.
Keep `~/.graphify/providers.json` tracked; it's config you own, not generated.

### Update trigger

**Manual and deliberate, not on every bootstrap.** The patches are the reason.
An unattended `--upgrade` against a forked qmd and a config-dependent graphify is
how you find out at 2 a.m. that the Ruby extractor is gone.

Which is why `01-setup-tools.sh` is being replaced rather than patched: it runs
`uv tool install --upgrade "$pkg"` for every entry on every bootstrap, which
makes provisioning non-deterministic and breaks the "second run completes in
< 5 seconds with zero state mutations" line in `BACKLOG_YADM_REBUILD.md`'s
definition of done. See item 2c — `tooling_uv_state: present` is that fix.

- [x] ~~Pin versions; install pins exactly, no `--upgrade`.~~ Done for uv in
      item 2c. Outstanding for cargo, npm and binaries.
- [ ] Separate `update-agent-tools` entry point: re-resolve, print an old→new
      diff, write bumped pins into `host_vars`. Updating becomes a commit, with
      a git record of when each tool changed and what broke after.
- [x] ~~Settle the manifest format.~~ Answered by item 2c: structured
      `host_vars` entries with `version:` / `git:`+`rev:` / (for binaries)
      `url:`+`sha256:`, validated by `meta/argument_specs.yml`. No line syntax
      needed.

**Layer:** lists → `host_vars`, Layer 1. Build deps (`build-essential`,
`node-gyp`, `python3`, node ≥22) → Layer 1 `base_packages`. Generated agent
registrations → neither; ignored.

---

## 2b. Python, uv, and CUDA — DECIDED 2026-08-11

**Caught live.** Mid-session, a `yadm bootstrap` on `popvm` was watched pulling
`nvidia-cublas` (403 MB), `nvidia-cudnn-cu13` (349 MB), `triton` (188 MB),
`torch` (502 MB) and nine more CUDA wheels — **~5 GB of GPU userspace into a CLI
tool's venv, on a virtio guest with no GPU.** The trigger was `uv tool install
docs2db`; `docs2db` depends on torch, and PyPI's default torch build on Linux is
the CUDA one.

That is the original 11 GB `pip --user` failure reproducing itself *inside the
mechanism built to prevent it*. `uv tool` isolated the venv, exactly as designed,
and the venv was still 5 GB of the wrong thing.

### The one-line fix

```bash
export UV_TORCH_BACKEND=auto
```

`auto` queries the installed **driver** and selects the matching PyTorch index;
with no GPU it falls back to CPU-only wheels. It is the setting that makes
`hardware_install_host_cuda: false` coherent — accelerator selection reads the
driver, so no host toolkit is needed to get the right wheels.

The uv docs state `--torch-backend` is `uv pip`-only. **That is stale.** Verified
against uv 0.12.3:

```
uv tool install --torch-backend <TORCH_BACKEND>
  [env: UV_TORCH_BACKEND=] [possible values: auto, cpu, cu132, cu130, cu129, ...]
```

- [ ] `export UV_TORCH_BACKEND=auto` in the shell config **and** at the top of
      `01-setup-tools.sh` — a bootstrap that doesn't source the shell config
      still has to get it.
- [x] ~~Reconsider `docs2db` on the uv-tools manifest.~~ **Dropped 2026-08-11.**
      A thing that depends on torch is an ML application wearing a CLI. Removed
      from the manifest rather than pinned to a CPU index.
- [ ] Audit the rest of the uv-tools manifest for the same shape — anything
      whose dependency tree reaches torch, transformers, or onnxruntime is
      Layer 3, not a CLI utility.

### uv itself is an unpinned dependency

`.tool-versions` pins `uv 0.9.28`; current is **0.12.3**. Item 1 already removes
that line (asdf goes Ruby-only), which leaves `01-setup-tools.sh` installing uv
from Astral's `install.sh` at floating latest. uv is the foundation of the entire
Python strategy and is currently the least-pinned thing in it.

- [ ] Pin uv explicitly in the tooling manifests (item 2a's format question) and
      install that version, rather than whatever `install.sh` serves that day.
- [ ] Note that available Python downloads are frozen per uv release — an old uv
      cannot install a new CPython even when asked.

### Python provenance — decided

`python-preference = "system"` in `~/.config/uv/uv.toml`. Noble's 3.12 is the
default interpreter; uv downloads a managed one only when a project pins a
version the system lacks. Not `only-system` — a project pinning 3.13 must still
work.

> Correction to a mid-session note: uv's **default** is `managed`, which prefers
> uv's own interpreters. `system` is the setting that means "system first."

### GPU Python boundary — hybrid, my call

No preference was expressed, so: **venv for inference, container for builds.**

uv hardlinks from `~/.cache/uv`, so N venvs sharing a torch build cost ~1× on
disk rather than N× — which removes most of the disk argument that produced the
container-only rule in `FORENSICS-REPORT.md` §8.3. On a T1200 with **4 GB of
VRAM**, the realistic workloads are embeddings, whisper, spacy and small-model
inference, and routing every one of those through a container image is friction
without a matching benefit.

Containers stay the answer for anything needing `nvcc`, anything without a
prebuilt wheel for your torch/CUDA pair, and anything that needs a CUDA
userspace pinned independently of the host driver. That last one is now the
*only* real argument for containers here, and it should be made on those grounds
rather than on GB.

Reversible: if the venv path drifts, tightening back to container-only is a
policy change, not a rebuild.

Worked templates for both paths: **`LAYER3-PYPROJECT.md`**.

### The CDI gap — FIXED 2026-08-11

The container half of that split **did not work**. `hardware` installed
`nvidia-container-toolkit` and `libnvidia-container-tools`; nothing ever ran
`nvidia-ctk cdi generate`, and `roles/containers` had no GPU awareness at all.
So `podman run --device nvidia.com/gpu=all` would have failed on a
freshly-provisioned machine, and the "CUDA belongs in a container" position in
`group_vars` had nothing behind it.

Fixed in this session:

- `roles/hardware/tasks/nvidia_cdi.yml` — generates `/etc/cdi/nvidia.yaml`,
  idempotently (generate to a candidate path, `cmp`, install only on change —
  `nvidia-ctk` has no check mode and always rewrites).
- Skips with an explanation when `nvidia-smi` can't reach the driver, which is
  the normal state before the first reboot after a driver install.
- Enables `nvidia-cdi-refresh.path`/`.service` where the toolkit ships them, so
  the spec regenerates on driver upgrade; warns loudly where it doesn't. A stale
  spec fails *quietly* — the container starts and simply sees no GPU.
- `roles/containers` gained a read-only readiness check: GPU present but no CDI
  spec now reports at provision time instead of at first use.
- New tag `cdi` for re-running just this after a driver change.

- [ ] **Exercise on `gir`, not `popvm`.** Same caveat as the System76 path — a
      virtio guest can't reveal any of this.
- [ ] Smoke test:
      `podman run --rm --device nvidia.com/gpu=all nvidia/cuda:13.0-base-ubuntu24.04 nvidia-smi`
- [ ] Confirm the CUDA minor in the pinned PyTorch index is one the System76
      driver supports. `nvidia-smi`'s "CUDA Version" is the driver's *ceiling*,
      not what's installed.

**Layer:** driver, toolkit, CDI spec, tool lists → Layer 1. `uv.toml` and the
shell's `UV_TORCH_BACKEND` → Layer 2 (files a tool reads from a fixed `$HOME`
path). Per-project torch index and extras → Layer 3.

---

## 3. Desktop apps (Flatpak)

46 apps installed across `flathub` and `fedora` remotes. Snapshot:
`flatpak-apps.txt`.

**You flagged that not all of these carry over — so this is a triage task, not a
migration task.** Suggested passes:

1. Drop anything from the `fedora` remote outright; that remote does not exist on Pop.
2. Sort the flathub set into keep / evaluate / drop. Anything last-launched more than
   a few months ago is a drop candidate.
3. ~~For the keepers, note which hold state worth preserving under `~/.var/app/<id>/`.~~
   **Resolved 2026-08-11 — Flatpak appdata is handled by
   [SaveDesktop](https://vikdevelop.github.io/SaveDesktop/), not restic.**
   `io.github.vikdevelop.SaveDesktop` is already installed (flathub, 4.1) and already
   in the `02-flatpaks.sh` app list, so the tool survives the wipe on its own.
   The `~/.var` restic exclusion stands and needs no revisiting.

   What still has to happen, because SaveDesktop is manual:

   - [ ] **Run a SaveDesktop export on `gir` before the wipe** and confirm where the
         archive lands. This is the one irreversible step in the whole plan — an
         un-run backup tool is the same as no backup tool.
   - [ ] Put the archive somewhere restic *does* cover, or somewhere off-machine.
         SaveDesktop writing into `~/.var` or a Flatpak-sandboxed path would put the
         backup inside the excluded tree.
   - [ ] Note SaveDesktop's periodic-save setting for the rebuilt machine, so this
         doesn't stay a thing you have to remember.

Then: a `flatpak` role or a `desktop_flatpaks` variable, plus adding the flathub
remote (`flatpak remote-add --user --if-not-exists flathub …` per System76's docs).

Also on the list, from the earlier audit — four packages were installed by hand from
downloaded RPMs and have no repo anywhere: `CherryStudio`, `hermes-desktop`,
`Multica`, `trackboi`. Pop has no RPM at all. Each needs a decision: flatpak
equivalent, rebuild from source, or accept the loss.

**Layer:** remote + app list → Layer 1. Per-app state under `~/.var` → Layer 2 or
backup restore.

---

## 4. Agentic CLI apps, plugins, skills

This is the largest and least-declared surface on the machine:

| Dir | Size | Files |
|---|---:|---:|
| `.hermes` | 17 G | 296,759 |
| `.gemini` | 8.6 G | 28,007 |
| `.antigravity` | 1.9 G | 16,522 |
| `.vibe` | 983 M | 19,505 |
| `.claude` | 898 M | 30,179 |
| `.codex` | 163 M | 5,861 |
| `.syncopated` | 97 M | 4,302 |
| `.config/opencode` | 73 M | 3,781 |
| `.crush` | 13 M | 228 |

**~30 GB across ~405,000 files.** Almost none of it is config; most is state, caches,
session logs, and cloned marketplaces.

`.claude` alone carries 8 plugin marketplaces (`claude-code-workflows`,
`claude-context-mode`, `claude-plugins-official`, `context-engineering-kit`,
`everything-claude-code`, `obsidian-skills`, `oh-my-mermaid`, `ruby-dev-plugin`) and
54 skills. The marketplaces are re-clonable and should not be backed up. The skills
and your own plugin work should be.

Work, per tool: separate **config** (small, declarative, belongs in yadm, often needs
`yadm encrypt` because it holds tokens) from **state** (large, regenerable, belongs in
neither backup nor yadm). `.hermes/profiles/*/` in particular holds 14 profiles each
with `.env` and `auth.json` — those must survive, and must be encrypted.

Full snapshot in `agent-tooling.txt`.

**Layer:** the CLI binaries → Layer 1, declared in `host_vars` (items 2, 2c).
Config and skills → Layer 2, authored content, encrypted where it holds tokens.
State → explicitly excluded from both.

---

## 4a. `hermes` role — containerized

**New 2026-08-11.** `.hermes` is 17 G across 296,759 files — the single largest
undeclared thing on the machine. The upstream install is
`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`, which drops a
uv-managed Python 3.11, a Node runtime, ripgrep and ffmpeg into `$HOME` and leaves
you with no way to say what version of anything you have. That is the thing to fix,
and the container is the way to fix it — not because containers are tidy, but because
**it splits one directory into three things that belong to three different owners.**

Upstream ships a compose file. Translated to this collection's terms:

| Piece | Layer | Owner |
|---|---|---|
| `hermes-agent` image | 1 | new `hermes` role |
| Quadlet `.container` units for `gateway run` and `dashboard` | 1 | new `hermes` role |
| `~/.hermes` bind mount → `/opt/data` | 2 | yadm (config), restic (nothing) |
| `profiles/*/{auth.json,.env,config.yaml}` | 2 | yadm **encrypted** — already in `encrypt` |
| Sessions, caches, state DB, skills index (the 17 G) | — | neither. Regenerable. |

### Design

Podman, rootless, quadlet — `containers_install_podman: true` is already the default
and `containers_install_docker: false` stays false. Quadlet gives systemd `--user`
units generated from declarative `.container` files, which is closer to how the rest
of this collection works than a compose file shelled out from a bootstrap script.

Upstream compose, for reference:

```yaml
gateway:    image: hermes-agent, network_mode: host,
            volumes: ~/.hermes:/opt/data, command: ["gateway","run"]
dashboard:  same image, command: ["dashboard","--host","127.0.0.1","--no-open"]
```

### Four things that will bite

1. **`--userns=keep-id` is mandatory.** Upstream says set `HERMES_UID=$(id -u)` so
   files in the bind mount stay writable on the host. That advice assumes *rootful*
   Docker. Under rootless Podman, in-container UID *n* maps to a subuid on the host,
   so following it verbatim gives you a `~/.hermes` owned by something in the
   100000+ range. `UserNS=keep-id` in the quadlet, then `HERMES_UID`/`HERMES_GID`
   set to `b08x`'s real uid/gid.
2. **Don't override the entrypoint.** The image's PID 1 is s6-overlay's `/init`,
   which runs the chown / profile-reconcile / dashboard-toggle hooks before any
   service starts. Quadlet `Exec=` appends to the entrypoint — verify that
   holds rather than assuming it.
3. **`loginctl enable-linger b08x`** or the gateway dies at logout. Layer 1, and easy
   to forget because it works fine while you're sitting at the machine.
4. **The image is built, not pulled** (`build: .`). The Dockerfile lives in the git
   checkout at `$HERMES_HOME/hermes-agent` — which is inside the very `$HOME` tree
   Layer 1 isn't supposed to touch. Options: build from a transient clone under
   `/var/lib/hermes-build`, or publish the image once to GHCR and have the role pull
   a tag. **The second is better** and removes the circularity entirely.

Also unresolved: the CLI. `hermes` (the TUI) still wants to be on `$PATH`. Either a
wrapper that `podman exec -it hermes hermes`, or accept a host install alongside the
container. Decide before writing the role — it changes whether Layer 2 still needs
the installer at all.

### Work

- [ ] Decide: build locally vs. publish to GHCR and pull a tag.
- [ ] `roles/hermes/` — image, two quadlet units, `enable-linger`, `~/.hermes` mode.
- [ ] `--userns=keep-id` verified against a real write from inside the container.
- [ ] CLI story: wrapper vs. host install.
- [ ] Confirm the 14 profiles decrypt into the bind mount and the gateway sees them.

---

## 5. Obsidian notebook migration

Two vaults:

| Vault | Size | Markdown files |
|---|---:|---:|
| `Notebook` | 8.0 G | 2,221 |
| `NotebookV2` | 278 M | 3 |

`Notebook` is the real one. 8 GB against 2,221 markdown files means the bulk is
attachments, not notes — worth knowing which, because it changes whether this is a
"copy the vault" job or a "prune then copy" job.

`NotebookV2` with 3 markdown files and 278 M looks like an abandoned start. Confirm
before carrying it.

Open questions:

- Is `NotebookV2` a migration you began and stopped, or a scratch experiment? If the
  former, finishing it may be the actual task here.
- Which plugins does the vault depend on, and are they all still maintained? A vault
  that renders correctly only under a specific plugin set is a reproducibility
  problem, and `obsidian-skills` in `.claude` suggests agent tooling reads this vault
  too.
- Does `.obsidian/` belong in yadm (config, portable) with the notes in a separate
  synced store?

**Layer:** notes are user data → backup and restore, not Ansible. `.obsidian/` config
→ arguably Layer 2.

---

## 6. Carried over from this session

- [ ] **Push `development`** — 11 commits, unpushed. The earlier audit's loudest
      finding was unpushed work, and this repo is now the thing that rebuilds the
      machine.
- [ ] **Exercise the System76 path on `gir`** post-install: vendor packages,
      `power-profiles-daemon` masking, `hardware_graphics_mode`, firmware `adm`
      group. None of it can be tested on a virtio guest.
- [ ] **Fix `ansible-lint` on `gir`** — CLI 2.18.2 vs python module 2.18.18rc1.
      Worked around this session via a throwaway venv at `/tmp/lintenv`; that
      workaround dies with `/tmp`.
- [ ] **Archive `ansible-collection-rhel-workstation-builder`** — still holds its
      collect scripts, `manifests/`, and `manifests-pre-update/`. Has no git remote.
- [x] ~~**Revisit the `~/.var` backup exclusion**~~ — closed 2026-08-11. SaveDesktop
      owns Flatpak appdata; the exclusion stands. Replaced by "run a SaveDesktop
      export before the wipe" (item 3).
- [ ] **Add a seam test** — four assertions that the Layer 1 → Layer 2 handoff
      actually happened. See `ANSIBLE-AND-YADM.md`; this is the gap that document
      identifies as the architecture's real weakness.
- [ ] **`NOPASSWD` sudo on `popvm`** was added for unattended runs. Do not carry that
      pattern to `gir`.
- [ ] Consider whether `main` should be fast-forwarded to `development`, or whether
      the collection work wants a release tag first.

---

## 7. Sequencing suggestion

Ordered by what blocks what:

1. Push `development`. Everything else assumes the collection is safe.
2. **Run the SaveDesktop export on `gir`** (item 3) and verify the archive lands
   somewhere restic covers. Irreversible-step-adjacent; do it early, not on wipe day.
3. Triage flatpaks and agent-tooling config-vs-state (items 3, 4) — these determine
   what the backup must include, and the backup runs before the wipe.
4. Write the manifests (items 2, 2a) in the YAML shape item 2c settled — the
   format question is answered, so this is no longer blocked. Then the `asdf`
   role + `04-asdf-ruby.sh` (item 1).
5. Obsidian (item 5) is independent of the rebuild — it can happen after.
6. Wipe, install Pop, run `bootstrap.yml` then `workstation.yml`, then exercise the
   System76 path and fix what the VM could not reveal.
7. **`hermes` role (item 4a) comes after the rebuild, not before.** It depends on
   `containers` being exercised on real hardware, and the `--userns=keep-id`
   behaviour can't be trusted from a virtio guest any more than the System76 path
   can. Keep the host install working until the container is proven.
