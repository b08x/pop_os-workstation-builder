# Building a Vagrant box from the Pop!_OS ISO

The default test box is Ubuntu 24.04 plus the System76 archive. It cannot test
two things (see `README.md`): the UEFI / `kernelstub` path, and anything that
branches on `ansible_distribution`. Building a box from the real ISO closes
both.

## Which ISO

Use **`pop-os_24.04_amd64_generic_27.iso`**, not the NVIDIA one.

The NVIDIA image preinstalls the proprietary driver, and `distinst` adds
`nvidia-drm.modeset=1` to the kernel command line and manages
`/var/lib/dkms/nvidia` when it detects that image. In a guest with no GPU that
is dead weight at best and a black screen at worst.
`inventory/host_vars/popvm.yml` sets `hardware_install_nvidia: false`, so none
of the NVIDIA code paths would be exercised even if the driver were there.

## What the ISO actually contains

Worth knowing before choosing an approach — verified by inspecting the image:

| Fact | Consequence |
|---|---|
| Casper live image, `live-media-path=/casper_pop-os_24.04_amd64_generic_debug_654` | Standard live boot, but the path is **release-specific**. It changes with every ISO respin. |
| `.disk/info` = `Pop_OS 24.04 "Noble Numbat" - Release amd64 (20260722)` | This is the 20260722 respin. |
| Installer is `pop-installer` + `distinst` / `distinst-v2` | Graphical, **not** subiquity. There is no `autoinstall`, no preseed, no kickstart. Packer's usual Ubuntu recipe does not apply. |
| `openssh-client` is present, `openssh-server` is **not** | Nothing can SSH *into* the live environment out of the box. This is the main obstacle to a fully automated Packer build. |
| No `pool/` directory on the ISO | Installing `openssh-server` in the live environment requires network access. |
| `distinst` handles the bootloader with `kernelstub --esp-path /boot/efi` (EFI) or `update-grub` (BIOS) | A **UEFI** install is what produces the systemd-boot + kernelstub layout `roles/hardware` targets. Install in UEFI mode or the whole exercise is pointless. |

## Recommended path: golden image, then package

Three scripts in `box/`. Only step 2's installer click-through is manual;
roughly 30 minutes end to end, most of it waiting.

### 1. Boot the installer

```
./test/vagrant/box/build-golden-image.sh ../pop-os_24.04_amd64_generic_27.iso
```

Creates a 40G qcow2 and boots the ISO with `--boot uefi`. A viewer window
opens (`virt-viewer pop-golden` if it does not).

In the installer:

* **Clean Install** onto the whole virtual disk. Do not hand-partition; the
  default UEFI layout is exactly what we want.
* Decline disk encryption. A LUKS box needs a passphrase at every boot, which
  makes it useless for unattended testing.
* Create the user **`vagrant`**, password **`vagrant`**.

  Keeping the box user as `vagrant` means `popify.sh` works unchanged — it
  already creates the real target account (`b08x`) by copying vagrant's
  `authorized_keys`. No `Vagrantfile` edits are needed to switch boxes.

Reboot into the installed system when it finishes.

### 2. Prepare the guest

Log in at the console and run:

```
sudo bash prepare-box.sh          # after copying it in, or paste it
```

This installs `openssh-server` (absent by default, which is why you cannot
just `scp` it in first), installs the Vagrant insecure public key, grants
passwordless sudo, disables unattended-upgrades and the apt timers so the box
does not race the `base` role, clears the machine-id and SSH host keys, and
zeroes free space so the image can be compressed.

Then `sudo poweroff`.

### 3. Package

```
./test/vagrant/box/package-box.sh
```

Sparsifies and compresses the image, writes `metadata.json` and a box-local
`Vagrantfile` that pins the OVMF firmware — **without it the box will not boot
at all**, because a UEFI-installed system handed the default SeaBIOS loader has
no bootloader to find — tars it up, and runs `vagrant box add`.

### 4. Use it

```
POPVM_BOX=pop-os/24.04 vagrant up
vagrant ssh -c 'lsb_release -is && ls -d /boot/efi && which kernelstub'
```

Expect `Pop`, `/boot/efi`, `/usr/bin/kernelstub`. At that point both fidelity
caveats in `README.md` are closed and should be deleted.

## The fully automated path, and why it is not the default

`distinst` is a CLI and it is present in the live squashfs, so a scripted
install is genuinely possible — this is not a GUI-only installer. Its real
interface, read out of the binary:

```
-s, --squashfs <path>     the squashfs image to install
-b, --block <dev>         disk to manipulate
-t, --new-table <dev:gpt|msdos>
-n, --new <...>           create a partition
-u, --use <...>           reuse an existing partition
-d, --delete <...>
-h, --hostname <name>     NOTE: -h is hostname, not help. Use --help.
-k, --keyboard <layout>
-l, --lang <locale>
-r, --remove <manifest>   packages to remove post-install
    --tz <zone>
    --force-efi / --force-bios / --no-efi-vars
    --test                validate the arguments without installing
```

Filesystems it accepts: `btrfs exfat fat16 fat32 linux-swap(v1) xfs lvm` plus
the usual ext family. Partition types: `primary`, `logical`. Tables: `gpt`,
`msdos`.

**Do not guess at the `--new` tuple grammar.** Use `--test`, which runs the
argument parsing and partitioning validation and stops before touching the
disk. That is the cheap way to discover the exact separator format for the
installed version rather than losing an afternoon to
`invalid number of arguments supplied to --new`.

The blocker is not `distinst`, it is getting to it: Packer drives a machine
over SSH, the live environment has no `openssh-server`, and installing one
needs a `boot_command` typed blind into a graphical live session plus working
egress. That is a lot of brittleness — tied to a `live-media-path` that changes
on every respin — to avoid one 20-minute click-through that you do once per
Pop!_OS release.

Revisit if box rebuilds become frequent. Until then the golden image wins.

## Housekeeping

The ISOs are ~3.5-3.9G. Keep them out of the repo — `.gitignore` already
covers `*.box`; do not add the ISOs to the tree either.
