#!/usr/bin/env bash
# SPDX-License-Identifier: MIT-0
# ============================================================================
# Step 3 of 3 -- turn the prepared, powered-off golden image into a
# vagrant-libvirt box and add it to the local box store.
#
#   ./test/vagrant/box/package-box.sh
#   POPVM_BOX=pop-os/24.04 vagrant up
# ============================================================================
set -euo pipefail

NAME="${GOLDEN_NAME:-pop-golden}"
IMG="${GOLDEN_IMG:-$HOME/.local/share/libvirt/images/${NAME}.qcow2}"
BOX_NAME="${BOX_NAME:-pop-os/24.04}"
OUT="${OUT:-$PWD/pop-os_24.04_libvirt.box}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

log() { printf '[package-box] %s\n' "$*"; }

[[ -f "${IMG}" ]] || { echo "no image at ${IMG}" >&2; exit 1; }

if virsh domstate "${NAME}" 2>/dev/null | grep -q running; then
  echo "${NAME} is still running -- 'sudo poweroff' inside the guest first" >&2
  exit 1
fi

# virt-sparsify reclaims the space prepare-box.sh zeroed; --compress then
# gets a 40G disk down to something in the 3-5G range.
log "sparsifying and compressing (slow)"
virt-sparsify --compress "${IMG}" "${WORK}/box.img"

VSIZE="$(qemu-img info --output=json "${WORK}/box.img" \
         | python3 -c 'import json,sys;print(json.load(sys.stdin)["virtual-size"]//(1024**3))')"
log "virtual size: ${VSIZE}G, on-disk: $(du -h "${WORK}/box.img" | cut -f1)"

cat > "${WORK}/metadata.json" <<META
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": ${VSIZE}
}
META

# The box carries its own UEFI firmware settings. A Pop!_OS installed in UEFI
# mode boots via systemd-boot; hand it the default BIOS SeaBIOS loader and it
# will not boot at all.
cat > "${WORK}/Vagrantfile" <<'BOXVF'
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.loader = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    libvirt.nvram  = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
  end
end
BOXVF

log "writing ${OUT}"
tar czf "${OUT}" -C "${WORK}" metadata.json Vagrantfile box.img

log "adding as ${BOX_NAME}"
vagrant box add --force --name "${BOX_NAME}" "${OUT}"

cat <<DONE

Done. Use it with:

    POPVM_BOX=${BOX_NAME} vagrant up

Then confirm the fidelity gaps are actually closed:

    vagrant ssh -c 'lsb_release -is && ls -d /boot/efi && which kernelstub'

Expect: Pop, /boot/efi, /usr/bin/kernelstub. Once that holds, drop the
caveats from test/vagrant/README.md.
DONE
