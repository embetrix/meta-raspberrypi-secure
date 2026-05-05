## Threat Model (Baseline)

This layer provides a security baseline. It defines what the *platform*
defends against: product-specific threat models built on top of this layer
must extend it with application assets, network exposure and physical
deployment considerations.

### Assets Protected

- **Boot chain integrity** only firmware, bootloader, kernel and
  initramfs signed by the platform owner will execute.
- **Root filesystem integrity** the rootfs is read-only and
  cryptographically verified at runtime via dm-verity/AVB.
- **Runtime file integrity** IMA/EVM appraises executables and
  their security-relevant attributes against signed reference values.
- **Data confidentiality at rest** the writable data partition is
  encrypted with dm-crypt using a key bound to the SoC (OTP / kernel
  trusted key) so the storage medium alone does not yield plaintext.
- **Device identity** each device has a unique ECDSA key in OTP,
  exposed via PKCS#11 usable for TLS and attestation.
- **Update integrity** A/B slots are atomically updated: only
  signed images are accepted failed updates will rollback.

### Attacker Model

The baseline assumes an attacker with one or more of the following
capabilities:

1. **Remote network attacker** can reach exposed services over the
   network: goal is code execution, persistence, or data exfiltration.
2. **Local non-privileged attacker** has shell access as a regular
   user (e.g., via a compromised service) goal is privilege escalation
   or persistence.
3. **Offline storage attacker** gains physical possession of the
   device's storage medium (SD card, eMMC) when powered off and goal is
   to read user data or modify the rootfs to gain code execution on
   next boot.
4. **Casual physical attacker** has temporary physical access to a
   running or powered-off device but no specialized equipment and goal
   is to bypass authentication or extract data via exposed interfaces
   (USB, UART, network).

### Defenses Provided

| Threat                                       | Defense                                  |
|----------------------------------------------|------------------------------------------|
| Unsigned firmware/bootloader execution       | RPi secure boot, OTP-locked public key   |
| Tampering with kernel/initramfs              | Signed boot.img signature verified by bootloader |
| Offline rootfs modification                  | dm-verity/AVB, root hash signature       |
| Tampering with userspace binaries at runtime | IMA appraise (enforced mode in `prod`)   |
| Tampering with security xattrs               | EVM (enforced mode in `prod`)            |
| Reading data from a stolen storage medium    | dm-crypt with SoC-bound key              |
| Loading unsigned kernel modules              | Module signing, lockdown                 |
| Persistence via A/B slot tampering           | Both slots signed and verified           |
| Unauthorized USB devices                     | USBGuard default-deny                    |
| Untrusted network ingress                    | nftables default-drop                    |
| Unauthorized SSH access                      | SSH CA-signed certificates only          |
| Loss of audit trail                          | auditd + persistent `/var/log`           |
| Unconstrained process privileges             | SELinux                                  |

### Out of Scope

The following are explicitly *not* defended against by this layer.
Products requiring protection against these must add hardware,
configuration, or process controls of their own.

- **Compromise of the GPU ROM or Broadcom bootcode** The Raspberry Pi
  root of trust is the closed-source first-stage loader in the SoC
  This layer takes that as given.
- **Physical attackers with specialized equipment**  bus probing,
  voltage/clock glitching, decapping, side-channel analysis (power,
  EM, timing), JTAG attacks if not fused off.
- **Cold-boot/DRAM remanence attacks** against unlocked device keys.
- **Loss or compromise of the platform signing keys** Once the OTP
  hash is fused, key compromise is unrecoverable. Key custody, HSM
  use, and rotation policy are the integrator's responsibility.
- **Supply-chain compromise of upstream sources**  oky,
  meta-raspberrypi, the kernel, or any third-party recipe. Mitigated
  partially by source URI hashes and not eliminated.
- **Vulnerabilities in application code shipped on top of this layer**
- **Denial-of-service attacks** including resource exhaustion and
  battery/thermal attacks.
- **Network-level attacks above the host** DNS hijacking, BGP
  hijacking, TLS interception by a trusted-but-malicious CA.
- **Information disclosure via legitimate interfaces** logs, metrics,
  error messages crafted by the integrator.
- **Insider threats** with access to signing keys or production
  provisioning infrastructure.

### Assumptions

The baseline holds only if:

- The `prod` security profile is selected for shipping images.
- Signing keys are generated on a trusted machine, kept offline or in
  an HSM, and never committed to source control.
- The OTP public-key hash is fused before deployment.
- The device-unique OTP ECDSA key is provisioned per device.
- Default configurations (firewall, USBGuard, SSH CA, SELinux) are
  not weakened downstream without an explicit risk decision.
- System time is reasonably correct (for certificate validation).

### What Integrators Must Add

Products built on this layer should perform their own threat-modeling
exercise covering at minimum:

- Application-level assets and trust boundaries.
- Network services exposed and their authentication model.
- Update server trust and rollback policy.
- Physical deployment environment and tamper response.
- Logging, monitoring, and incident response.
- Regulatory requirements (e.g., CRA, RED, FDA, IEC 62443).
