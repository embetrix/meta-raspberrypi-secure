# meta-raspberrypi-secure

[![CI](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml/badge.svg?branch=scarthgap)](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml)

A Yocto layer that builds security-hardened Raspberry Pi images on top of [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi/log/?h=scarthgap).

## Features

- `Secure boot` with a full chain of trust rooted in the RPi bootloader
- `Encrypted writable partitions` (dm-crypt + key bound to the SoC)
- `Runtime integrity` via IMA/EVM
- `Read-only rootfs` with state isolated to authenticated/encrypted data partition
- `A/B partitioning` for atomic updates of boot and root slots
- `Hardened kernel & userspace` (sysctl, systemd, OpenSSH, busybox)
- `Network & USB defenses` (default-drop firewall, USBGuard, audit)

## Quick Start

### 1. Generate signing keys

Generates secure-boot, AVB, IMA/EVM, kernel-module and SSH-CA keys, and writes a ready-to-use kas fragment `kas-signing-keys.yml`:

```sh
./scripts/genkey-helper.sh rpi-secure-keys
```

### 2. Configure the build

- `KAS_MACHINE`: `raspberrypi5` *(default)*, `raspberrypi-cm5-io-board`, `raspberrypi4-64`.
- `SECURITY_PROFILE`: `dev` *(default)* or `prod`.

### 3. Build

Two options:

* Standalone build directly from this layer using the provided kas configuration.

* Integrate into your own layer by adding:

```conf
# in your local.conf
DISTRO = "rpi-secure"
```

#### Standalone build

Using [kas](https://kas.readthedocs.io/en/latest/userguide/getting-started.html) directly:

```sh
KAS_MACHINE=raspberrypi5 SECURITY_PROFILE=prod \
    kas build kas-rpi-secure.yml:kas-signing-keys.yml
```

Or using the [kas container](https://kas.readthedocs.io/en/latest/userguide/kas-container.html):

```sh
KAS_MACHINE=raspberrypi5 SECURITY_PROFILE=prod \
    kas-container build kas-rpi-secure.yml:kas-signing-keys.yml
```

### 4. Flash

Flash the image to an SD card or USB drive with [bmap-tools](https://github.com/yoctoproject/bmaptool) (replace with your block device: e.g. `/dev/sdX` or `/dev/mmcblk0`):

```sh
sudo bmaptool copy \
    build/tmp/deploy/images/<MACHINE>/rpi-secure-image-base-<MACHINE>.rootfs.wic.bz2 \
    /dev/sdX
```
## Layers dependencies

- [poky](https://git.yoctoproject.org/poky/log/?h=scarthgap)
- [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi/log/?h=scarthgap)
- [meta-openembedded](https://github.com/openembedded/meta-openembedded/tree/scarthgap)
- [meta-security](https://git.yoctoproject.org/meta-security/log/?h=scarthgap)
- [meta-selinux](https://git.yoctoproject.org/meta-selinux/log/?h=scarthgap)
- [meta-avb](https://github.com/embetrix/meta-avb/tree/scarthgap)

## Supported Hardware

| Model                       | MACHINE                      |
|-----------------------------|------------------------------|
| Raspberry Pi 4 Model B      | `raspberrypi4-64`            |
| Raspberry Pi 5              | `raspberrypi5`               |
| Compute Module 5 (IO Board) | `raspberrypi-cm5-io-board`   |

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) for details.
