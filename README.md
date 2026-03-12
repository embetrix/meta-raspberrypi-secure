# meta-raspberrypi-secure

An add-on Yocto layer on top of `meta-raspberrypi` for security hardening.

## Description

This layer provides security-focused configurations and overrides for Raspberry Pi based embedded systems built with the Yocto Project. It is not standalone as it depends on `meta-raspberrypi`, `meta-security`, and `meta-integrity` and is meant to be stacked on top of them.

## Dependencies

- openembedded-core (`meta`)
- meta-raspberrypi
- meta-integrity
- meta-security

Compatible with Yocto **Scarthgap** release.

## What it provides

- **Kernel hardening**: dm-crypt/dm-verity, IMA/EVM, kernel module signing, netfilter, security options, and optional Wi-Fi/Bluetooth disabling
- **systemd hardening**: stripped-down PACKAGECONFIG, coredump disable, dm-crypt/LUKS support
- **busybox hardening**: disabled network daemons, insecure clients, raw memory access, user management, and debug features
- **Hardened fstab**: restrictive mount options (noexec, nodev, nosuid) on all pseudo-filesystems, securityfs for IMA/EVM
- **USBGuard**: default-deny USB device policy

## Usage

Include this layer in your `bblayers.conf` or use the provided `kas-rpi-secure.yml` with [kas](https://kas.readthedocs.io/):

```sh
kas build kas-rpi-secure.yml
```
