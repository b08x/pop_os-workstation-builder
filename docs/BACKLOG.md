# Backlog — `b08x.workstation`

**Opened:** 2026-08-10
**Context:** Layer 1 is built and verified. Everything below is Layer 2 and Layer 3 —
the parts the collection deliberately does *not* own, which still need a plan before
`gir` gets wiped.

Inventories captured while `gir` was still Fedora 43 live in
`../workstation-forensics/manifests/`. Those lists stop existing after the wipe,
so triage against the snapshot rather than against memory.

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

## 1. asdf and Ruby 4

**Finding worth acting on:** asdf is declared but not provisioned. `~/.tool-versions`
asks for `ruby 4.0.1` and `uv 0.9.28`; asdf 0.19.0 (the Go rewrite) is installed at
`/usr/bin/asdf` with shims at `/opt/asdf/shims`, but **zero plugins are installed and
zero rubies are built**. Meanwhile `/usr/bin/ruby` is 3.4.10 from the distro.

So today every `ruby` invocation silently resolves to system 3.4.10 while the
declaration says 4.0.1. That divergence carries forward unless it's decided.

Open questions:

- Is Ruby 4.0.1 the actual target, or is that line stale? 4.0 is recent enough that
  gem compatibility is worth checking against the projects that matter
  (`sfl-engine`, `ruby-dev-plugin`, `rubygemdb`, `RubyLLM-SFL-RAG`).
- asdf 0.19 is the Go rewrite and its plugin/shim model differs from the old shell
  version — the shim dir at `/opt/asdf/shims` is system-wide, which is a Layer 1
  concern, while plugins and installed versions are Layer 2.
- Does asdf earn its place at all, given `uv` already owns Python and there are
  16 cargo binaries managed outside it? A single-language version manager for one
  language is a fair outcome.

Decide: asdf for Ruby only, or `ruby-install`/`chruby`, or system Ruby plus per-project
`bundle path`.

**Layer:** asdf itself and `/opt/asdf` → Layer 1 (a role). Plugins, versions,
`.tool-versions` → Layer 2 (yadm). Gems → Layer 3 (project `Gemfile.lock`).

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
- **uv tool:** `ansible-builder ansible-navigator devstart docs2db graphifyy
  linux-mcp-server mistral-vibe notebooklm-py omega13 rubygemdb seishun`. Several are
  your own projects; those need their repos reachable before reinstall works.
- **npm -g:** includes two `-> ./...` symlinks into `~/WorkspaceV3/code-insights`,
  and four entries with empty versions (`@open-gitagent/gapman`, `codeburn`,
  `hermes-paperclip-adapter`, `code-insights-workspace`) — local installs that will
  not resolve from a registry.

Work: turn each list into a declarative manifest under `~/.config/tooling/`
(`cargo-tools.txt`, `uv-tools.txt`, `npm-global.txt`), tracked in yadm, consumed by the
yadm bootstrap script. Some of these are also available as apt packages on noble
(`bottom`, `eza`, `just`, `sd`, `ripgrep`) — prefer apt where the version is current,
since that moves them into Layer 1 where they're cheaper to maintain.

**Layer:** manifests → Layer 2. Anything moved to apt → Layer 1 (`base_packages`).

---

## 3. Desktop apps (Flatpak)

46 apps installed across `flathub` and `fedora` remotes. Snapshot:
`flatpak-apps.txt`.

**You flagged that not all of these carry over — so this is a triage task, not a
migration task.** Suggested passes:

1. Drop anything from the `fedora` remote outright; that remote does not exist on Pop.
2. Sort the flathub set into keep / evaluate / drop. Anything last-launched more than
   a few months ago is a drop candidate.
3. For the keepers, note which hold state worth preserving under `~/.var/app/<id>/`.
   The current backup excludes `~/.var` wholesale, so **any Flatpak app config you
   care about is not currently in restic.** Worth revisiting that exclusion before
   the wipe, or exporting specific app dirs by hand.

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

**Layer:** the CLI binaries → Layer 2 manifests (item 2 above). Config → Layer 2,
encrypted. State → explicitly excluded from both.

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
- [ ] **Revisit the `~/.var` backup exclusion** before the wipe if any Flatpak app
      state matters (see item 3).
- [ ] **`NOPASSWD` sudo on `popvm`** was added for unattended runs. Do not carry that
      pattern to `gir`.
- [ ] Consider whether `main` should be fast-forwarded to `development`, or whether
      the collection work wants a release tag first.

---

## 7. Sequencing suggestion

Ordered by what blocks what:

1. Push `development`. Everything else assumes the collection is safe.
2. Triage flatpaks and agent-tooling config-vs-state (items 3, 4) — these determine
   what the backup must include, and the backup runs before the wipe.
3. Decide the Ruby/asdf question (item 1) and write the tool manifests (item 2).
   These become the yadm bootstrap script, which the `dotfiles` role already calls.
4. Obsidian (item 5) is independent of the rebuild — it can happen after.
5. Wipe, install Pop, run `bootstrap.yml` then `workstation.yml`, then exercise the
   System76 path and fix what the VM could not reveal.
