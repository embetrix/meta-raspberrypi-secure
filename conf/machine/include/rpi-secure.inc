# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#

# Security profile "dev" or "prod"
RPI_SECURITY_PROFILE ?= "dev"

# Restrict to supported machines only
INHERIT += "rpi-secure-machine-compat"

# Bootloader configuration
ENABLE_WATCHDOG         = "1"
ENABLE_USB_MAX_CURRENT  = "1"
ENABLE_TRYBOOT_AB       = "1"
ENABLE_SPI_BUS          = "1"
ENABLE_I2C              = "1"
LOCK_DEVICE_KEY         = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '1', '0', d)}"
ENABLE_UART             = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '0', '1', d)}"
DISABLE_SPLASH          = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '1', '0', d)}"
# On purpose not locking the device key in OTP This is a one-way operation and should be done with caution !!
# check for more options in
# https://github.com/raspberrypi/usbboot/blob/master/secure-boot-recovery5/config.txt
PROGRAM_PUBLIC_KEY      = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '0', '0', d)}"
PROGRAM_JTAG_LOCK       = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '0', '0', d)}"

# TPM support
MACHINE_FEATURES += "tpm"
ENABLE_TPM_SLB9670   = "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', '1', '0', d)}"
MACHINE_EXTRA_RRECOMMENDS      += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'packagegroup-security-tpm2', '', d)}"
RPI_KERNEL_DEVICETREE_OVERLAYS += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'overlays/tpm-slb9670.dtbo', '', d)}"

# Console disable serial console login in production
SERIAL_CONSOLES_DEFAULT := "${SERIAL_CONSOLES}"
CONSOLE_VERBOSE ?= "loglevel=7 systemd.journald.forward_to_console=1 systemd.journald.max_level_console=warning"
CONSOLE_SILENT  ?= "console=null quiet loglevel=0"
SERIAL_CONSOLES  = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '', '${SERIAL_CONSOLES_DEFAULT}', d)}"
CONSOLE_SELECT   = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '${CONSOLE_SILENT}', '${CONSOLE_VERBOSE}', d)}"

# Kernel Command Line
CMDLINE_ROOTFS  = "ro"
IMA_APPRAISE    = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'enforce', 'log', d)}"
CMDLINE:append  = " ${CONSOLE_SELECT} ima_appraise=${IMA_APPRAISE}"

# Remove debug-tweaks in production
EXTRA_IMAGE_FEATURES:remove = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'debug-tweaks', '', d)}"

# Initramfs Bundle
INITRAMFS_IMAGE        ?= "rpi-secure-initramfs-image"
INITRAMFS_IMAGE_NAME   ?= "rpi-secure-initramfs-image-${MACHINE}.rootfs"
INITRAMFS_IMAGE_BUNDLE  = "1"

# Ship the bundled kernel+initramfs image as the firmware-loaded kernel
IMAGE_BOOT_FILES += "${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin;${SDIMG_KERNELIMAGE}"

# No kernel image inside the rootfs
RDEPENDS:${KERNEL_PACKAGE_NAME}-base = ""

# Raspberry Pi Secure Boot configuration
RPI_SECURE_BOOT_SIGN = "1"
IMAGE_CLASSES += "rpi-secure-boot"
INHERIT += "rpi-signing-keys"
IMAGE_BOOT_FILES_DEFAULT := "${IMAGE_BOOT_FILES}"
IMAGE_BOOT_FILES_SECURE_BOOT = "boot.img boot.sig"

# Boot files selection:
#   dev  + secure boot: DEFAULT + SECURE_BOOT (all files for fallback when secure boot is disabled using recovery)
#   prod + secure boot: SECURE_BOOT only (boot.img, boot.sig, EEPROM, recovery)
#   secure boot off:    DEFAULT only
IMAGE_BOOT_FILES = "${@bb.utils.contains('RPI_SECURE_BOOT_SIGN', '1', \
                    bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', \
                        '${IMAGE_BOOT_FILES_SECURE_BOOT}', \
                        '${IMAGE_BOOT_FILES_DEFAULT} ${IMAGE_BOOT_FILES_SECURE_BOOT}', d), \
                    '${IMAGE_BOOT_FILES_DEFAULT}', d)}"

# IMA/EVM Rootfs Signing
INHERIT += "ima-evm-rootfs"

# AVB/DM-Verity configuration
IMAGE_CLASSES += "avb-verity"
IMAGE_FSTYPES += " ${ROOTFS_TYPE}.avbverity.gz"

# Extra Runtime Packages
MACHINE_EXTRA_RRECOMMENDS += " \
                        raspi-utils \
                        raspi-utils-raspinfo \
                        raspi-utils-rpieepromab \
                        raspi-utils-rpifwcrypto \
                        "

# CVE checks
INHERIT += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'cve-check', '', d)}"
include conf/distro/include/cve-extra-exclusions.inc

# WKS file
WKS_FILES = "raspberrypi-secure.wks.in"
ROOTFS_TYPE="erofs"

# Files for the boot partition selector
WICVARS:append = " IMAGE_BOOT_PARTITION_FILES"
IMAGE_BOOT_PARTITION_FILES = "autoboot.txt \
                              recovery.bin;_recovery.bin_ \
                              pieeprom-recovery.bin;_pieeprom.bin_ \
                              pieeprom-recovery.sig;_pieeprom.sig_ \
                              pieeprom.bin.signed;_pieeprom.upd_ \
                              pieeprom.upd.hashsig;_pieeprom.upd.sig_ \
                              readme.txt"

# Device Tree Hardening
# Keep only the DTB and overlays required by the actual hardware
# This reduces the kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
