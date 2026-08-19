# Role: `containers`

**Container runtimes and hardware group membership.**

Installs Podman by default. Docker is opt-in because it adds a root daemon and a second storage pool.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `containers_user` | `str` | true | `None` | Login name receiving group membership and lingering. |
| `containers_install_podman` | `bool` | false | `true` | Install the Podman toolchain. |
| `containers_podman_packages` | `list` | false | `None` | Podman APT packages. |
| `containers_install_docker` | `bool` | false | `false` | Install Docker. Adds the user to the root-equivalent docker group. |
| `containers_docker_packages` | `list` | false | `None` | Docker APT packages. |
| `containers_enable_lingering` | `bool` | false | `true` | Enable systemd lingering so rootless units survive logout. |
| `containers_user_groups` | `list` | false | `None` | Supplementary groups for hardware access. |
| `containers_verify_gpu` | `bool` | false | `true` | Report when a GPU is present but no CDI specification exists. Read-only. Generation belongs to the hardware role, which runs first. |
| `containers_cdi_spec_path` | `str` | false | `/etc/cdi/nvidia.yaml` | CDI specification checked by the GPU readiness report. |
