# Documentation

Index of documentation for the `meta-raspberrypi-secure` layer.

## Where to start

Everyone should read [threat-model.md](threat-model.md) first: it defines what this layer defends against and contextualizes every other doc.

Then, depending on your role:

- **Integrators** (building images with this layer): [integration.md](integration.md), then [profiles.md](profiles.md) and [keys.md](keys.md).
- **Operators** (deploying & managing devices): [operations.md](operations.md), then [updates.md](updates.md).
- **Security reviewers**: [architecture.md](architecture.md), then the subsystem docs below.

## Concepts

- [architecture.md](architecture.md): Component overview and boot chain.
- [profiles.md](profiles.md): `dev` vs. `prod` security profiles.
- [partitions.md](partitions.md): On-disk layout and A/B slots.

## Subsystems

- [secure-boot.md](secure-boot.md): Signed boot chain and OTP provisioning.
- [secure-storage.md](secure-storage.md): dm-verity rootfs, dm-crypt data, IMA/EVM.
- [keys.md](keys.md): Canonical catalog of all keys used by the layer.
- [updates.md](updates.md): A/B update flow and rollback.
- [network.md](network.md): Firewall, USBGuard, SSH.
- [kernel-hardening.md](kernel-hardening.md): Kernel config, sysctl, LSMs, patches.
- [compliance.md](compliance.md): SBOM, CVE scanning, audit, logs.

## Guides

- [integration.md](integration.md): Add this layer to your build.
- [operations.md](operations.md): Runbook for provisioning, updates, recovery.
