# meta-raspberrypi-secure

[![CI](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml/badge.svg?branch=scarthgap)](https://github.com/embetrix/meta-raspberrypi-secure/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Yocto layer that provides a security-hardened baseline for Raspberry Pi images, extending [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi/log/?h=scarthgap) layer with secure boot, verified and encrypted storage, runtime integrity and a hardened kernel and userspace.

## Features

- Hardware root of trust with signed boot chain anchored in the SoC boot ROM
- Read-only authenticated rootfs with state isolated to data partitions
- Encrypted writable data partitions (dm-crypt + trusted key bound to the SoC)
- Runtime integrity via IMA/EVM
- A/B partitioning for atomic updates of boot and root slots
- Hardened kernel & userspace (SELinux, sysctl, systemd, OpenSSH, busybox)
- Network & USB protection (default-drop firewall, USBGuard)
- Optional TPM 2.0 support (Infineon SLB9670)
- Compliance & auditability (Audit, persistent logs, SBOM, CVE scanning)

## Quick Start

### 1. Generate signing keys

Generates Secure-boot, AVB-DMVerity, IMA/EVM, Kernel-Modules and SSH-CA keys and writes a ready-to-use kas fragment `kas-signing-keys.yml`:

```sh
./tools/genkey-helper.sh
```

> **Warning:** store them securely and keep an offline backup even for development.

### 2. Configure the build

Two variables drive the build: `KAS_MACHINE` selects the target hardware (see [Supported Hardware](#supported-hardware)) and `SECURITY_PROFILE` selects the hardening level:

| Profile            | Use case | Behavior                                                                             |
|--------------------|----------|--------------------------------------------------------------------------------------|
| `dev` *(default)*  | Bring-up | Serial console, debug tweaks, IMA/EVM in log/fix mode, SELinux permissive            |
| `prod`             | Release  | Silent console, JTAG & device key locked, kernel/userspace hardening, enforcing IMA/EVM & SELinux, SSH cert-only auth |

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

Each device can generate a unique ECDSA key pair stored in OTP and could be used for device identity and TLS certificates backed by hardware:

```sh
rpi-fw-crypto genkey --key-id 1 --alg ec
```

> **Warning:** This is irreversible. The key is written once into OTP memory and can never be changed or erased.

The key is accessible via the [rpifwcrypto-pkcs11](https://github.com/embetrix/rpifwcrypto-pkcs11) PKCS#11 module for device identity and TLS operations and via the kernel trusted key subsystem for storage encryption (dm-crypt).

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
| Raspberry Pi 5              | `raspberrypi5`               |
| Compute Module 5 (IO Board) | `raspberrypi-cm5-io-board`   |
| Raspberry Pi 4 Model B      | `raspberrypi4-64`            |

## License

This project is licensed under the MIT License see the [LICENSE](LICENSE) for details.
