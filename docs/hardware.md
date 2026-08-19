# Role: `hardware`

**System76 hardware enablement and boot parameters.**

Installs System76 daemons and the vendor NVIDIA driver, sets the hybrid graphics profile, and manages kernel arguments via kernelstub. Host CUDA is off by default; use a container instead.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `hardware_install_system76` | `bool` | false | `true` | Install System76 vendor packages. Set false on non-System76 hardware. |
| `hardware_system76_packages` | `list` | false | `None` | System76 vendor APT packages. |
| `hardware_system76_services` | `list` | false | `None` | System76 systemd units to enable, if present after install. |
| `hardware_install_nvidia` | `bool` | false | `true` | Install the vendor NVIDIA driver and container toolkit. |
| `hardware_user` | `str` | false | `None` | Login name added to the firmware admin group. |
| `hardware_mask_power_profiles_daemon` | `bool` | false | `true` | Mask power-profiles-daemon so system76-power can start. GNOME installs it by default and the two conflict. |
| `hardware_firmware_admin_group` | `str` | false | `adm` | Group the System76 firmware daemon requires for its callers. |
| `hardware_graphics_mode` | `str` | false | `hybrid` | Graphics profile applied via system76-power. COSMIC is designed around hybrid and has no graphical switcher. |
| `hardware_nvidia_packages` | `list` | false | `None` | NVIDIA driver packages. Keep this to a single source. |
| `hardware_nvidia_container_packages` | `list` | false | `None` | Packages granting containers access to the GPU. |
| `hardware_generate_cdi_spec` | `bool` | false | `true` | Generate the CDI specification that lets containers request the GPU. Without it, nvidia-container-toolkit is installed but "podman run --device nvidia.com/gpu=all" fails. |
| `hardware_cdi_spec_path` | `str` | false | `/etc/cdi/nvidia.yaml` | Destination for the generated CDI specification. |
| `hardware_cdi_mode` | `str` | false | `auto` | Discovery mode passed to "nvidia-ctk cdi generate". |
| `hardware_cdi_smoke_test_tag` | `str` | false | `None` | nvidia/cuda image tag quoted in the post-generation hint. Cosmetic; appears in a debug message and pulls nothing. |
| `hardware_install_host_cuda` | `bool` | false | `false` | Install the CUDA toolkit onto the host filesystem. Off by default. The driver ships a basic CUDA runtime already, and a host toolkit layered under user-space installs duplicates it. Prefer an nvidia/cuda container image with nvidia-container-toolkit. |
| `hardware_host_cuda_packages` | `list` | false | `None` | Host CUDA packages, used only when hardware_install_host_cuda is true. |
| `hardware_manage_kernel_params` | `bool` | false | `true` | Manage kernel arguments through kernelstub. |
| `hardware_kernel_params` | `list` | false | `None` | Kernel arguments to ensure are present in the boot entry. |
