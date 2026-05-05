# meta-raspberrypi-secure

[![CI](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml/badge.svg?branch=scarthgap)](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml)

A Yocto layer that builds security-hardened Raspberry Pi images on top of [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi/log/?h=scarthgap).

## Features

- Secure boot with a full chain of trust rooted in the RPi bootloader
- Read-only rootfs with state isolated to data partitions
- Encrypted writable data partitions (dm-crypt + key bound to the SoC)
- Runtime integrity via IMA/EVM
- A/B partitioning for atomic updates of boot and root slots
- Hardened kernel & userspace (sysctl, systemd, OpenSSH, busybox)
- Network & USB protection (default-drop firewall, USBGuard, audit)

## Quick Start

### 1. Generate signing keys

Generates secure-boot, AVB, IMA/EVM, kernel-module and SSH-CA keys, and writes a ready-to-use kas fragment `kas-signing-keys.yml`:

```sh
./scripts/genkey-helper.sh
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
KAS_MACHINE=raspberrypi5 SECURITY_PROFILE=dev \
    kas build kas-rpi-secure.yml:kas-signing-keys.yml
```

Or using the [kas container](https://kas.readthedocs.io/en/latest/userguide/kas-container.html):

```sh
KAS_MACHINE=raspberrypi5 SECURITY_PROFILE=dev \
    kas-container build kas-rpi-secure.yml:kas-signing-keys.yml
```

### 4. Flash

Flash the image to an SD card or USB drive with [bmap-tools](https://github.com/yoctoproject/bmaptool) (replace with your block device: e.g. `/dev/sdX` or `/dev/mmcblk0`):

```sh
sudo bmaptool copy \
    build/tmp/deploy/images/<MACHINE>/rpi-secure-image-base-<MACHINE>.rootfs.wic.bz2 \
    /dev/sdX
```
### 5. Enable Secure Boot

After flashing and booting the image, secure boot can be activated on the device using the `rpi-secureboot` utility:

```sh
# Check current secure boot status
rpi-secureboot status

# Enable secure boot (stages signed EEPROM and reboots)
rpi-secureboot enable
```

This flashes a signed EEPROM image with `SIGNED_BOOT=1` via the recovery mechanism. Once enabled, only boot images signed with the key generated in step 1 will be accepted.

To make secure boot **permanent** (irreversible), the public key hash must be burned into OTP fuses this is not done automatically. While OTP fuses remain unprogrammed, secure boot can be toggled:

```sh
# Disable secure boot (only if OTP fuses are not programmed)
rpi-secureboot disable
```

> **Warning:** Programming OTP fuses is irreversible. Once burned, secure boot cannot be disabled and only firmware signed with the matching key will boot.

### 6. Provision Device-Unique ECDSA Key

Each device can generate a unique ECDSA key pair stored in OTP, used for device identity and TLS certificates backed by hardware:

```sh
rpi-fw-crypto genkey --key-id 1 --alg ec
```

> **Warning:** This is irreversible. The key is written once into OTP memory and can never be changed or erased.

The key is accessible via the `rpifwcrypto-pkcs11` PKCS#11 module for device identity and TLS operations and via the kernel trusted key subsystem for storage encryption (dm-crypt).

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

MIT. See [LICENSE](LICENSE) for details.
