# Role: `base`

**Core system configuration for a Pop!_OS workstation.**

Sets the timezone, applies APT tuning, optionally disables core dumps, and installs the Layer 1 CLI toolchain.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `base_timezone` | `str` | false | `America/New_York` | IANA timezone name applied via the timezone module. |
| `base_disable_coredumps` | `bool` | false | `true` | Write a systemd coredump drop-in setting Storage=none. |
| `base_apt_upgrade` | `str` | false | `dist` | Upgrade mode handed to ansible.builtin.apt. |
| `base_apt_cache_valid_time` | `int` | false | `3600` | Seconds before the APT cache is considered stale. |
| `base_apt_install_recommends` | `bool` | false | `true` | Value for APT::Install-Recommends. Desktop stability wants this true. |
| `base_apt_install_suggests` | `bool` | false | `false` | Value for APT::Install-Suggests. |
| `base_apt_pipeline_depth` | `int` | false | `5` | Value for Acquire::http::Pipeline-Depth. |
| `base_packages` | `list` | false | `None` | APT packages installed at system scope. |
