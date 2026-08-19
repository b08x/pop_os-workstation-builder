# Does Ansible + yadm earn its complexity?

**Opened:** 2026-08-11
**Revised:** 2026-08-11, same day — the first answer was wrong in an instructive way
**Companion to:** `../../workstation-forensics/ANSIBLE-YADM-SPLIT.md`, `BACKLOG.md`

---

## Short answer

Keep both. yadm is scoped by **enumeration**, not by rule.

> **yadm owns:**
> 1. Anything you authored — shell functions, aliases, prompt, agent skills and
>    personas, tuned app configs.
> 2. Anything a tool reads from a fixed `$HOME` path at runtime —
>    `.tool-versions`, `.npmrc`, `.gemrc`, `.graphify/providers.json`.
> 3. Anything that needs `yadm encrypt` — SSH, GPG, the fourteen Hermes
>    profiles, `.claude.json`, `.codex/auth.json`.
>
> **Ansible owns everything else**, including installs into `$HOME`.

Three checks, answerable by looking rather than arguing.

## Why this replaces the rule that was here this morning

The first version of this document proposed an **audience** rule — "Ansible owns
what is identical for every user of this image; yadm owns what encodes *your*
preferences" — as a correction to an older **privilege** rule ("Ansible owns
root, yadm owns `$HOME`").

The audience rule sorted correctly. It also had to be *argued* every time. In
one session it was applied to flatpaks, asdf, the Hermes container, and the tool
manifests: four correct answers, four separate arguments. A rule that yields the
right answer only after a debate is doing less work than it looks like it's
doing. Worse, it adjudicated against a hypothetical second user of a collection
that has exactly one workstation, one VM, and one human.

The enumeration is not a philosophical improvement. It is a shorter thing to
check.

### The count that settled it

Of 513 files yadm tracks today:

| | files | |
|---|---:|---|
| `.config/yadm` | **227** | yadm's own bootstrap machinery |
| `.vibe` + `.hermes` | 178 | agent tooling |
| `.config/{mpv,ranger,kitty,Thunar,input-remapper,…}` | ~58 | app configs |
| zsh rc files + `.local/share/zsh` + `.aliases` | 48 | shell |

**44% of what yadm tracks is yadm's own scaffolding** — `bootstrap.d`, the gum
helpers, the pipeline. That is the work moving into Ansible roles. Remove it and
what remains is shell, agent tooling, and app configs.

So the scope above was not imposed on yadm. It is what yadm reduces to once the
installs leave. The mandate was inflated by machinery that was already on its
way out.

---

## Why two tools is not the redundancy it looks like

There is a real boundary between them, and it isn't taste.

**The tools run at different times, in different identities, with different
prerequisites available.** Ansible runs against a machine that has root, a
network, and no user session. yadm runs against a machine that has your SSH key
and a decrypted GPG key — neither of which exists at install time. That is not
a preference about tooling; it is a property of the install.

The `dotfiles` role already admits this. `dotfiles_require_clone` defaults to
`false` because the first run on a fresh machine legitimately cannot clone. That
default is not a wart to be fixed; it is the boundary rendering itself honestly.
Any single-tool system would have to encode the same ordering constraint. You'd
just be calling the two halves "pre" and "post" instead of Layer 1 and Layer 2,
and you'd have written the second half yourself.

Note this is now the **only** ordering dependency between the two. Once the tool
lists moved to `host_vars`, the `tooling` role stopped reading anything out of
`$HOME` — so it runs before `dotfiles` and works on a machine with no SSH key.
The clone is the whole seam.

**Secrets are the strongest argument, and they only point one way.** There are
14 Hermes profiles, each with `.env` and `auth.json`, plus `.claude.json`,
`.codex/auth.json`, `.ssh/id_ed25519`, four GPG artifacts, and a KeePass
database. `~/.config/yadm/encrypt` already covers them.

The Ansible-only alternative is `ansible-vault`, which means one of two things:

- template secrets out of vault vars — the secrets now live in the collection
  repo, and the collection repo is the thing you push to GitHub; or
- `ansible-pull` with a vault password on the box — you've moved the problem to
  "how does the vault password get there," which is the same bootstrap problem,
  minus the encryption-at-rest that yadm gives you for free.

yadm wins here because the secret and the dotfile are the *same object*. There's
no templating step to keep in sync, no second inventory of what's sensitive.

**The merge costs are concrete in both directions.** Ansible-only means ~500
`copy`/`template` tasks or one `synchronize`, and `$HOME` loses its git history.
yadm-only means `sudo` inside bootstrap scripts, which is precisely the pattern
`TASK-101` excised from the old `~/.config/yadm`. Both directions are worse than
the seam.

---

## What the split actually costs

Not nothing. Being honest about it:

| Cost | Severity |
|---|---|
| Two repos, two histories, two lint stacks, two idioms (YAML vs. bash + gum) | ongoing, low — and shrinking as `bootstrap.d` migrates |
| A change spanning the seam needs two commits | low now; the seam is one operation, the clone |
| Layer 3 is enforced by convention, not mechanism | **the real risk** |

That last row is what's left. `PIP_REQUIRE_VIRTUALENV=true` is a *mechanism* —
`pip install` outside a venv refuses, and the 11 GB `site-packages` problem
cannot recur. Tool declarations are *conventions*: nothing stops a
`cargo install` that never reaches `host_vars`. Drift comes back through the
conventions, not through the two-tool split. If you spend effort anywhere on
this architecture, spend it there.

The earlier version of this document called the untested Layer 1 → Layer 2
handoff the real gap. That has largely dissolved rather than been fixed: with
the tool lists in `host_vars`, the only thing crossing the boundary is the yadm
clone itself, which `dotfiles` already handles explicitly.

---

## What the enumeration decides, without argument

The three items the audience rule had to reason about:

**Flatpaks.** The `--system` remote is Ansible's — it's an install. The app list
is Ansible's too, for the same reason. Only per-app state under `~/.var` is
yadm-adjacent, and `BACKLOG.md` item 3 gives that to SaveDesktop instead. Under
the old rule this took a paragraph about whether an app list counts as identity.

**asdf.** `/opt/asdf` and the binary are installs → Ansible. `~/.tool-versions`
is read by asdf from a fixed `$HOME` path → yadm, category 2. No argument about
whether a shim directory serving one user is "identity."

**Hermes.** The image and its quadlet unit are installs → Ansible. The encrypted
profiles are category 3 → yadm. The 17 GB of session state is neither, and is
excluded from both. Same answer as before, reached by looking instead of
reasoning.

The point isn't that the enumeration gets different answers. It's that it gets
them without a debate, which is the property a governing rule is supposed to
have.

---

## The amendment

Replace the governing rule in `ANSIBLE-YADM-SPLIT.md` with:

> **Layer 1 (Ansible)** — every install, wherever it lands. Most need root;
> some, like user-scope CLI tooling, do not. `become_user` reaches `$HOME`.
>
> **Layer 2 (yadm)** — three things, enumerated: what you authored; what a tool
> reads from a fixed `$HOME` path; what needs `encrypt`.
>
> **Layer 3 (project)** — anything a specific repo needs to run.
> Enforced by mechanism where possible, convention where not.

When something is ambiguous, check it against the three-item list. If it isn't
on the list, it's an install.

---

## Verdict

The split is sound and the tools are correctly chosen — that was never really in
doubt. What was wrong was governing it with a rule that needed interpreting.
yadm ends up smaller than it started this document, not because its mandate was
cut but because 44% of what it tracked was scaffolding for a job that has moved.

Stop relitigating the tool choice. The remaining work is Layer 3, where the
guardrails are still conventions.
