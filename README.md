# meta-raspberrypi-secure

A Yocto layer for building security-hardened Raspberry Pi images. It provides
full-disk encryption, verified boot, integrity measurement, and
defense-in-depth configurations on top of `meta-raspberrypi`.

## Supported Hardware

- Raspberry Pi 4 Model B & Compute Module 4
- Raspberry Pi 5 & Compute Module 5

## Dependencies

| Layer                | Branch     |
|----------------------|------------|
| openembedded-core    | scarthgap  |
| meta-poky            | scarthgap  |
| meta-raspberrypi     | scarthgap  |
| meta-openembedded    | scarthgap  |
| meta-security        | scarthgap  |
| meta-integrity       | scarthgap  |

## Quick Start

Build with [kas](https://kas.readthedocs.io/):

```sh
KAS_MACHINE=raspberrypi4-64 kas build kas-rpi-secure.yml
```

Or use the provided Docker environment:

```sh
docker build -t kas-builder .
docker run -v $(pwd):/work kas-builder kas build kas-rpi-secure.yml
```

The output image is at `build/tmp/deploy/images/<machine>/rpi-secure-image-<machine>.rootfs.wic.bz2`.

## Security Profiles

The layer supports two profiles controlled by `RPI_SECURITY_PROFILE`:

| Feature                    | `dev` (default)      | `prod`               |
|----------------------------|----------------------|----------------------|
| Serial console (UART)      | Enabled              | Disabled             |
| Console output             | Verbose (loglevel=7) | Silent               |
| IMA appraise mode          | `log`                | `enforce`            |
| Root filesystem type       | ext4                 | EROFS (read-only)    |
| Secure boot key generation | Auto (debug keys)    | Manual (supply keys) |
| CVE scanning               | Off                  | On                   |
| `debug-tweaks`             | Present              | Removed              |
| u-Boot hardening           | Off                  | On                   |
| Busybox hardening          | Off                  | On                   |
| Kernel hardening           | Off                  | On                   |

## Security Architecture

### Secure Boot

Boot firmware, kernel, device trees, and overlays are packed into a signed
`boot.img` with an RSA-2048 PKCS#1v1.5 SHA-256 signature (`boot.sig`).
The Raspberry Pi bootloader verifies the signature before loading anything.

In production, supply your own signing key:
```
RPI_SECURE_BOOT_SIGN_KEY = "/path/to/secure-boot-sign.key"
```

### A/B Update Partitions

The GPT disk layout provides atomic updates:

| # | Name     | Size   | Filesystem | Purpose                     |
|---|----------|--------|------------|-----------------------------|
| 1 | boot     | 512 MB | FAT32      | Firmware + boot slot config |
| 2 | bootA    | 512 MB | FAT32      | Signed boot image (slot A)  |
| 3 | bootB    | 512 MB | FAT32      | Signed boot image (slot B)  |
| 4 | rootA    | 2 GB   | ext4/EROFS | Root filesystem (slot A)    |
| 5 | rootB    | 2 GB   | ext4/EROFS | Root filesystem (slot B)    |
| 6 | data     | 2 GB   | ext4       | Encrypted persistent data   |
| 7 | backups  | 2 GB   | ext4       | Encrypted backups           |

Slot selection is read from the device tree at boot (`/proc/device-tree/chosen/bootloader/partition`).

### Full-Disk Encryption (LUKS2)

All writable partitions (root, update, data, backups) are encrypted with
LUKS2 dm-crypt. On first boot, the initramfs encrypts the root partition
in-place.

Key derivation (strongest to weakest):
1. **OTP HMAC-SHA256** — RPi firmware computes HMAC using a fused OTP private
   key and the storage device CID, binding the key to both the SoC and the
   specific SD/eMMC/NVMe hardware.
2. **SHA-256 of serial + CID** — Fallback when OTP key is not provisioned.
3. **SHA-256 of serial** — Last resort when CID is unavailable (USB boot).

### IMA/EVM Integrity

Every file on the root filesystem is signed at build time with an asymmetric
key (IMA). Extended verification metadata is protected by EVM. At runtime:

- Executables, shared libraries, firmware, and kernel modules must carry
  valid signatures before loading.
- The IMA policy is loaded by the initramfs with the root filesystem UUID
  baked in.
- EVM is locked in signature-verification mode (`0x80000002`).

In production, supply your own keys:
```
IMA_EVM_PRIVKEY = "/path/to/privkey_ima.pem"
IMA_EVM_X509    = "/path/to/x509_ima.der"
```

### Kernel Module Signing

Kernel modules are signed with ECDSA at build time. The kernel rejects any
module without a valid signature (`MODULE_SIG_FORCE=y`).

### Kernel Hardening (production)

The `security-harden.cfg` fragment enables 70+ kernel options including:

- **Memory**: `INIT_ON_ALLOC`, `INIT_ON_FREE`, `INIT_STACK_ALL_ZERO`,
  `SLAB_FREELIST_HARDENED`, `RANDOM_KMALLOC_CACHES`
- **ARM64**: PAN, TTBR0 unmapping, Spectre mitigations,
  `RODATA_FULL_DEFAULT_ENABLED`
- **Control flow**: Clang CFI, Shadow Call Stack
- **Lockdown**: `LOCK_DOWN_KERNEL_FORCE_INTEGRITY`
- **LSMs**: Yama, Landlock
- **BPF**: Unprivileged BPF disabled, JIT hardening
- **Disabled**: COMPAT_BRK, DEVKMEM, USERFAULTFD, HIBERNATION, IO_URING,
  KPROBES, KGDB, MAGIC_SYSRQ, KALLSYMS, PROFILING

### Busybox Hardening (production)

Dangerous applets are disabled: network daemons (httpd, ftpd, telnetd, tftpd,
inetd, dnsd, ntpd, dhcp), insecure clients (telnet, ftp), user management
(adduser, deluser, su, login, getty), raw memory access, and SUID support.

### Firewall (iptables)

Default-drop policy on INPUT, OUTPUT, and FORWARD chains for both IPv4 and
IPv6:

- **SSH**: Rate-limited to 3 connections/minute, burst 5
- **HTTPS**: Allowed from RFC 1918 private networks only, 25/min rate,
  30 concurrent connections max
- **ICMP/ICMPv6**: Essential types only (destination unreachable, time exceeded,
  echo) with rate limiting
- **DNS/NTP/DHCP**: Outbound only
- All drops are logged via syslog and audit

### USB Device Control (USBGuard)

Default-block policy (`ImplicitPolicyTarget=block`). Only explicitly
whitelisted USB devices are allowed. Audit events are logged to the Linux
audit subsystem.

### Audit

100+ audit rules covering:

- Filesystem tampering (`/etc/passwd`, `/etc/shadow`, `/etc/ssh/`, `/etc/audit/`)
- Kernel module operations (init, finit, delete)
- Privilege escalation (setuid, setgid)
- All program execution (execve)
- Process injection (ptrace)
- Network activity (socket, connect, bind, listen)
- Time manipulation
- Access violations (EACCES, EPERM)
- Log and reboot protection

Logs are forwarded to syslog via audispd-plugins for journald integration.

### systemd Hardening

- Core dumps disabled (`DumpCore=no`, `DefaultLimitCORE=0`)
- Hardware watchdog enabled (15s runtime, 10min reboot)
- Journal persistence with size limits (256 MB system, 64 MB runtime)
- Stripped `PACKAGECONFIG`: removed hibernate, machined, nss-mymachines, utmp

### sysctl Hardening

Applied via `/etc/sysctl.d/90-security.conf`:

- Kernel pointer hiding (`kptr_restrict=2`)
- dmesg restriction, SysRq disabled
- Yama ptrace scope 2 (admin only)
- eBPF unprivileged disabled, JIT hardened
- No IP forwarding, SYN cookies, reverse path filtering
- Source routing and redirects blocked
- Martian packet logging, RFC 1337 TIME-WAIT hardening

### OpenSSH Hardening

- TCP/agent forwarding disabled
- Root login by key only (`prohibit-password`)
- MaxSessions 2, ClientAliveCountMax 2
- VERBOSE logging
- SSH Certificate Authority support (`TrustedUserCAKeys`)
- Host keys persisted on the encrypted data partition
- sshd starts only after time synchronization (certificate validity)

### Hardened Mounts

All pseudo-filesystems mounted with restrictive options:

```
proc     hidepid=2,nosuid,nodev,noexec
sysfs    nosuid,nodev,noexec
tmpfs    noexec,nodev,nosuid,strictatime
devpts   noexec,nosuid
```

Data and backup partitions mounted with `noexec,nodev,nosuid`.

### Read-Only Root with Persistent Storage

The root filesystem is mounted read-only. Writable state is isolated to
the LUKS-encrypted data partition and exposed via bind mounts:

- `/var/data/etc/ssh/keys` → `/etc/ssh/keys`
- `/var/data/etc/certs` → `/etc/certs`
- `/var/data/etc/systemd/network` → `/etc/systemd/network`
- `/var/data/var/log` → `/var/log`
- `/var/data/etc/wpa_supplicant` → `/etc/wpa_supplicant` (when wifi enabled)

### Hardware RNG

`rng-tools` feeds entropy from the hardware RNG (`/dev/hwrng`) to the kernel
entropy pool. The iproc-rng200 driver is built into the kernel for RPi 4/5.

### PKCS#11 & OTP Crypto

- **rpifwcrypto-pkcs11**: PKCS#11 module exposing RPi firmware OTP ECDSA keys
  to applications via standard PKCS#11 interfaces.
- **pkcs11-provider**: OpenSSL 3.x provider enabling transparent use of
  hardware tokens and smartcards.
- OpenSSL is configured to load the PKCS#11 provider automatically.

### Machine Identity

The systemd machine-id is deterministically derived from the hardware serial
number (`SHA-256` truncated to 32 hex characters), passed to systemd at boot
via `--machine-id=`. No state is written to disk.

### NTP Time Synchronization

`systemd-timesyncd` is configured with:
- Primary: `time.cloudflare.com`
- Fallback: `time.google.com`, `nts.netnod.se`, `ptbtime1.ptb.de`

### CI/CD

A Jenkinsfile is provided for automated builds with Docker-based agents,
parameterized machine/image selection, and artifact archival.

## Initramfs Boot Flow

```
mount_early_fs → get_boot_slot → derive_key → encrypt_rootfs (first boot)
→ mount root → mount data (LUKS) → mount backups (LUKS)
→ setup_integrity (IMA/EVM) → switch_root
```

## Production Checklist

Before deploying to the field:

- [ ] Set `RPI_SECURITY_PROFILE = "prod"`
- [ ] Replace all debug keys (secure boot, IMA/EVM, kernel module signing)
- [ ] Provision OTP key on each device (`rpi-fw-crypto genkey`)
- [ ] Lock OTP key readout (`lock_device_private_key=1`)
- [ ] Replace default user passwords
- [ ] Replace development SSH CA key
- [ ] Update USBGuard whitelist for target hardware
- [ ] Review and tighten iptables rules for deployment network
- [ ] Enable watchdog and A/B boot (`ENABLE_WATCHDOG`, `ENABLE_TRYBOOT_AB`)

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) for details.
