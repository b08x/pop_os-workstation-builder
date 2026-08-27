# Disposable test VM

`vagrant up` from the repository root boots the `popvm` host that
`inventory/hosts.ini` and `inventory/host_vars/popvm.yml` already describe,
then runs `playbooks/bootstrap.yml` followed by `playbooks/workstation.yml`
against it over SSH -- the same path a real machine takes.

## Prerequisites

```
vagrant plugin install vagrant-libvirt
```

libvirt/KVM only. The host already runs it, and it is the only provider here
that can eventually boot a real UEFI Pop!_OS image.

## Use

```
vagrant up                 # boot, popify, provision
vagrant provision          # re-run both playbooks -- this is the idempotence check
vagrant ssh                # log in as vagrant
ssh b08x@192.168.41.42     # log in as the provisioned account
vagrant destroy -f         # throw it away
```

Knobs, all environment variables read by the `Vagrantfile`:

| Variable | Default | Meaning |
|---|---|---|
| `POPVM_BOX` | `bento/ubuntu-24.04` | base box |
| `POPVM_NAME` | `popvm` | hostname and `--limit` target |
| `POPVM_IP` | `192.168.41.42` | static address, must match `hosts.ini` |
| `POPVM_MEMORY` | `8192` | MiB |
| `POPVM_CPUS` | `4` | vCPUs |
| `POPVM_DISK` | `40` | GiB backing file |
| `POPVM_USER` | `b08x` | must match `workstation_user` |
| `POPVM_PROVISION` | `1` | set `0` for a bare guest |

## What this does and does not prove

Proves:

* every role runs to completion on a clean Debian-family system,
* the run is idempotent (`vagrant provision` a second time reports no changes),
* APT candidates resolve for `pop-*` and `system76-*`, because
  `popify.sh` adds `ppa:system76/pop`.

Does not prove:

* **It is not Pop!_OS.** The box is Ubuntu 24.04 plus the System76 archive.
  `ansible_distribution` reports `Ubuntu`. The playbook gates on
  `ansible_os_family == "Debian"` (`playbooks/workstation.yml:31`), so this is
  invisible to the assert -- but any future task that branches on
  `ansible_distribution` will take the wrong branch here.
* **No UEFI.** The bento box is MBR/BIOS-partitioned, so the
  `kernelstub` / systemd-boot path that `host_vars/popvm.yml` deliberately
  keeps enabled cannot run. Closing this needs a box built from the Pop!_OS
  ISO.
* **No GPU and no System76 hardware.** `host_vars/popvm.yml` turns both off.
  The NVIDIA CDI and firmware-daemon paths are untested here by design.

The first two are closable. See [BUILDING-A-POP-BOX.md](BUILDING-A-POP-BOX.md)
for building a real UEFI Pop!_OS box from the ISO, then:

```
POPVM_BOX=pop-os/24.04 vagrant up
```
