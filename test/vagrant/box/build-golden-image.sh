#!/usr/bin/env bash
# SPDX-License-Identifier: MIT-0
# ============================================================================
# Step 1 of 3 -- boot the Pop!_OS ISO in a UEFI guest so you can run the
# installer once by hand. Everything after the install is scripted.
#
#   ./test/vagrant/box/build-golden-image.sh ../pop-os_24.04_amd64_generic_27.iso
#
# UEFI is the entire point. A BIOS install gives you GRUB; a UEFI install
# gives you systemd-boot managed by kernelstub, which is the code path
# roles/hardware actually targets and which no Ubuntu base box can provide.
# ============================================================================
set -euo pipefail

ISO="${1:?usage: $0 /path/to/pop-os_24.04_amd64_generic_27.iso}"
NAME="${GOLDEN_NAME:-pop-golden}"
IMG="${GOLDEN_IMG:-$HOME/.local/share/libvirt/images/${NAME}.qcow2}"
SIZE="${GOLDEN_SIZE:-40G}"
MEMORY="${GOLDEN_MEMORY:-4096}"
VCPUS="${GOLDEN_VCPUS:-2}"

[[ -f "${ISO}" ]] || { echo "no such ISO: ${ISO}" >&2; exit 1; }

case "${ISO}" in
  *nvidia*)
    cat >&2 <<'WARN'
WARNING: that is the NVIDIA ISO.

Use the *generic* ISO for the test box. The NVIDIA image preinstalls the
proprietary driver and distinst adds nvidia-drm.modeset=1 to the kernel
command line; in a guest with no GPU that is dead weight at best and a
black screen at worst. inventory/host_vars/popvm.yml sets
hardware_install_nvidia: false anyway, so none of it would be exercised.

Ctrl-C now, or wait 10 seconds to continue anyway.
WARN
    sleep 10
    ;;
esac

mkdir -p "$(dirname "${IMG}")"

if [[ -f "${IMG}" ]]; then
  echo "refusing to clobber existing ${IMG} -- move it aside first" >&2
  exit 1
fi

echo "creating ${SIZE} disk at ${IMG}"
qemu-img create -f qcow2 "${IMG}" "${SIZE}" >/dev/null

virsh destroy    "${NAME}" 2>/dev/null || true
virsh undefine   "${NAME}" --nvram 2>/dev/null || true

echo "launching installer -- a viewer window will open"
exec virt-install \
  --name "${NAME}" \
  --memory "${MEMORY}" \
  --vcpus "${VCPUS}" \
  --cpu host-passthrough \
  --disk "path=${IMG},bus=virtio,format=qcow2" \
  --cdrom "${ISO}" \
  --boot uefi \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --noautoconsole \
  --wait -1
