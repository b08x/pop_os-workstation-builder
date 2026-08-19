# Role: `tooling`

**User-scope CLI tooling declared in host_vars.**

Installs the CLI tools named in tooling_uv_tools into the target user's home. The list is per-host inventory data, not a dotfile. yadm is scoped to authored content; a version-pinned package list is a description of installs. See docs/ANSIBLE-AND-YADM.md. Needs no root -- become_user reaches $HOME. No ordering dependency on the dotfiles role. Proof of concept. uv only. See docs/TOOLING-ROLE-PROOF.md.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `tooling_manage` | `bool` | false | `true` | Master switch for the role. |
| `tooling_user` | `str` | true | `None` | Login name whose $HOME receives the tools. |
| `tooling_manage_uv` | `bool` | false | `true` | Manage uv and the Python CLI tools it installs. |
| `tooling_uv_version` | `str` | false | `0.12.3` | uv release to install. Pinned deliberately. Available Python downloads are frozen per uv release, so this also decides which CPythons uv can install. |
| `tooling_uv_asset` | `str` | false | `None` | Release asset filename for this platform. |
| `tooling_uv_base_url` | `str` | false | `None` | Base URL for uv release downloads. |
| `tooling_uv_checksum` | `str` | false | `None` | sha256 of the uv asset. Empty downloads unverified, with a warning. |
| `tooling_uv_install_dir` | `str` | false | `.local/bin` | Destination for the uv binaries, relative to home. |
| `tooling_uv_tools` | `list` | false | `[]` | Tools to install. Per-host data; declare in host_vars. Each entry takes name, plus either version (PyPI pin) or git and rev. Optional with is a list of extra dependencies. |
| `tooling_uv_state` | `str` | false | `present` | present installs the pinned version and leaves it alone. latest re-resolves on every run, which makes provisioning non-deterministic. Updating should be a separate deliberate act. |
| `tooling_uv_torch_backend` | `str` | false | `auto` | Value for UV_TORCH_BACKEND on every uv invocation. auto reads the installed driver and falls back to CPU-only wheels. Without it, any tool that transitively depends on torch pulls the Linux default CUDA build. |
| `tooling_uv_python_preference` | `str` | false | `system` | Value for UV_PYTHON_PREFERENCE. system prefers the distribution interpreter. Note uv's own default is managed, which prefers uv's interpreters instead. |
