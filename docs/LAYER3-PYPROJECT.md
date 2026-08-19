# Layer 3 reference — `pyproject.toml` for this machine

**Opened:** 2026-08-11
**Applies to:** `gir` — System76, NVIDIA T1200 Laptop (Turing, 4 GB VRAM), Pop!_OS
**Companion to:** `BACKLOG.md` item 2b, `ANSIBLE-AND-YADM.md`

Layer 1 and Layer 2 both stop at the project boundary and point here. This is
the thing they point at.

---

## The rules this encodes

1. **Nothing goes into `~/.local/lib/python3.x/site-packages`. Ever.**
   Enforced by `~/.config/pip/pip.conf` → `require-virtualenv = true`.
2. **No host CUDA toolkit.** `hardware_install_host_cuda: false`. The driver
   ships the runtime; wheels bring their own userspace.
3. **Every project declares its own accelerator.** Not the machine, not the
   shell, not a global default.

---

## Global uv settings — Layer 2, `~/.config/uv/uv.toml`

```toml
# Prefer the interpreter noble ships; download a managed one only when a
# project asks for a version the system does not have. Keeps the common case
# free of a 40 MB download and keeps `python3` meaning one thing.
python-preference = "system"

# Managed downloads stay available, just not preferred.
python-downloads = "automatic"
```

> **Correction to an earlier note in this session:** uv's `python-preference`
> default is `managed`, which *prefers uv's own* interpreters. The setting that
> means "system first, uv-managed when pinned" is `system`. `only-system` would
> forbid managed downloads entirely, which is not what you want — a project
> pinning 3.13 should still work.

Shell environment, also Layer 2:

```bash
export PIP_REQUIRE_VIRTUALENV=true     # mechanism, not convention
export UV_TORCH_BACKEND=auto           # see below — this one matters
```

---

## `UV_TORCH_BACKEND=auto` — the setting that prevents the 11 GB

`auto` makes uv query the **installed driver** and pick the matching PyTorch
index; with no GPU it falls back to CPU-only wheels. That is exactly the right
behaviour for a machine whose policy is "driver on the host, toolkit nowhere."

It also works on `uv tool install`, despite the uv docs saying `--torch-backend`
is `uv pip`-only. Verified against uv 0.12.3:

```
uv tool install --torch-backend <TORCH_BACKEND>
  [env: UV_TORCH_BACKEND=] [possible values: auto, cpu, cu132, cu130, cu129, ...]
```

**Why this is not optional.** Without it, `uv tool install docs2db` on a
GPU-less VM resolves the Linux default torch build and pulls `nvidia-cublas`
(403 MB), `nvidia-cudnn-cu13` (349 MB), `triton` (188 MB), `torch` (502 MB) and
nine more CUDA wheels — roughly 5 GB of GPU userspace into a *CLI tool's* venv,
on a machine with no GPU. That is the original 11 GB failure reproducing itself
inside the mechanism meant to prevent it.

Set it in the shell config **and** in `01-setup-tools.sh` before the manifest
loop, so a bootstrap run that doesn't source the shell config still gets it.

---

## Project template — CPU-only

Most of what this machine actually runs. 4 GB of VRAM does not train anything;
it does embeddings, whisper, spacy, small-model inference — and a good deal of
that is faster to keep on CPU than to fight the memory ceiling.

```toml
[project]
name = "example"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "torch>=2.13.0",
]

[tool.uv.sources]
torch = [{ index = "pytorch-cpu" }]

# explicit = true confines this index to packages pinned to it. Without it,
# every transitive dependency gets resolved against the PyTorch mirror too,
# which is slower and occasionally surprising.
[[tool.uv.index]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
explicit = true
```

## Project template — CUDA, switchable

For the projects that genuinely want the T1200. The extras make the accelerator
a deliberate flag (`uv sync --extra cu130`) rather than an ambient property of
whichever machine you cloned onto — which matters because this repo is meant to
be reproducible on a machine that isn't this one.

```toml
[project]
name = "example-gpu"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = []

[project.optional-dependencies]
cpu   = ["torch>=2.13.0", "torchvision>=0.28.0"]
cu130 = ["torch>=2.13.0", "torchvision>=0.28.0"]

[tool.uv]
conflicts = [[{ extra = "cpu" }, { extra = "cu130" }]]

[tool.uv.sources]
torch = [
  { index = "pytorch-cpu",   extra = "cpu" },
  { index = "pytorch-cu130", extra = "cu130" },
]
torchvision = [
  { index = "pytorch-cpu",   extra = "cpu" },
  { index = "pytorch-cu130", extra = "cu130" },
]

[[tool.uv.index]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
explicit = true

[[tool.uv.index]]
name = "pytorch-cu130"
url = "https://download.pytorch.org/whl/cu130"
explicit = true
```

```bash
uv sync --extra cpu       # laptop on battery, or the VM
uv sync --extra cu130     # the T1200
```

**Pin `cu130` to the driver, not to fashion.** The CUDA minor version in the
index must be one the installed driver supports. Check the ceiling with
`nvidia-smi` — the "CUDA Version" it prints is the *maximum* the driver
handles, not what's installed. Bump the index only after the driver moves.

---

## When a container is the right answer instead

The venv path handles inference. Reach for a container when:

- Something needs `nvcc` — building a custom CUDA extension, or any package
  without a prebuilt wheel for your torch/CUDA pair.
- You need a CUDA userspace pinned independently of the machine's driver, for
  reproducing someone else's results.
- The dependency set is hostile enough that isolating the whole userspace is
  cheaper than resolving it.

```bash
podman run --rm --device nvidia.com/gpu=all \
  nvidia/cuda:13.0-base-ubuntu24.04 nvidia-smi
```

That command depends on `/etc/cdi/nvidia.yaml`, which the `hardware` role now
generates. If it fails with "no such device", run
`ansible-playbook playbooks/workstation.yml --tags cdi`.

For prebuilt GPU extensions (`flash-attn`, `deepspeed`, `vllm`) the Astral GPU
index is worth trying before reaching for a container — it publishes wheels
built against specific CUDA/torch pairs:

```bash
uv add flash-attn --index astral-cu130=https://wheels.astral.sh/simple/cu130/
```

---

## On disk cost — the reason the rule relaxed

uv **hardlinks** packages out of `~/.cache/uv` into each venv. Ten projects
sharing one torch build cost roughly one torch on disk, not ten, provided the
cache and the venvs share a filesystem. That is the difference from the old
`pip --user` situation, and it removes most of the disk argument for
container-only GPU work.

What it does *not* remove is the reproducibility argument. A venv's CUDA
userspace is a function of the driver present when it was resolved; a
container's is pinned in the image. That distinction is now the whole reason to
reach for a container, and it should be reached for on those grounds rather than
on GB.

Keep `~/.cache/uv` excluded from restic and out of yadm — it is regenerable by
definition, and it is large precisely when it is working correctly.
