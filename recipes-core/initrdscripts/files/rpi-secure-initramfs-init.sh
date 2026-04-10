#!/usr/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# rpi secure initramfs init script:
#   mount_early_fs     - Mount devtmpfs, tmpfs, proc, sysfs, securityfs
#   get_boot_slot      - Detect A/B boot slot from device tree
#   derive_key         - Derive LUKS2 key from OTP HMAC or serial fallback
#   encrypt_rootfs     - First-boot rootfs encryption (plain to LUKS2)
#   setup_avb_verity   - AVB signature verification and dm-verity setup
#   mount_data_luks    - First-boot data partitions encryption
#   setup_integrity    - Import IMA/EVM keys and load appraise policy
#   switch_root        - Switch to the real root filesystem
#

#set -x

export PATH=$PATH:/sbin:/usr/sbin

BOOT_DEV=""
BOOTACTIVE_DEV=""
BOOTUPDATE_DEV=""
ROOT_DEV=""
UPDATE_DEV=""
DATA_DEV=""
BACKUPS_DEV=""

ROOT_DM_NAME="root"
UPDATE_DM_NAME="update"
DATA_DM_NAME="data"
BACKUPS_DM_NAME="backups"
VERITY_DM_NAME="verity-root"

ROOT_MNT="/root"
BOOT_MNT="/boot"
BOOTUPDATE_MNT="/boot-update"
DATA_MNT="/var/data"
BACKUPS_MNT="/var/backups"

OPT_ROOT="ro,noatime"
OPT_PART="noexec,nodev,nosuid"

IMA_POLICY="/etc/ima/ima-policy"
IMA_X509="/etc/keys/x509_ima.der"
EVM_X509="/etc/keys/x509_evm.der"
IMA_MANIFEST="/etc/ima-signatures.manifest"
EVM_MANIFEST="/etc/evm-signatures.manifest"

BOOT_SLOT="/proc/device-tree/chosen/bootloader/partition"
BOOT_MODE="/proc/device-tree/chosen/bootloader/boot-mode"

HW_SERIAL="/proc/device-tree/serial-number"
CID=""

ENC_KEY_HEX=""
MACHINE_ID=""

# Partition numbers for A/B slots, data and backups
# following wic configuration in rpi-secure.wks
BOOT=1
BOOT_SLOT_A=2
BOOT_SLOT_B=3
ROOT_SLOT_A=4
ROOT_SLOT_B=5
DATA_PART=6
BACKUPS_PART=7

TIMEOUT=40

OTP_KEY_ID=1

# dm-integrity: set to "hmac-sha256"
# to enable block-level tamper detection
# Disable for better RW performance
DM_INTEGRITY=""

AVB_PUBKEY="/etc/avb/avb_pubkey.bin"

# Init
INIT="/sbin/init"

# Source library files
LIBDIR="/usr/libexec/rpi-secure"
. "$LIBDIR/init-common.sh"
. "$LIBDIR/init-crypto.sh"
. "$LIBDIR/init-integrity.sh"

klog "Starting Initramfs..."
mount_early_fs
get_boot_slot

# Check root device
klog "Root device: $ROOT_DEV"
if [ -z "$ROOT_DEV" ]; then
	fatal "cannot get root device"
fi

# wait for slow block devices (USB...)
await_blockdev "$ROOT_DEV"

# Required to make pipe work in shell
ln -s /proc/self/fd /dev/fd

# Derive and cache the LUKS2 key once
derive_key

if ! cryptsetup isLuks "$ROOT_DEV" 2>/dev/null; then
	encrypt_rootfs "$ROOT_DEV" "$UPDATE_DEV" "$ROOT_DM_NAME" "$UPDATE_DM_NAME"
else
	inject_key | cryptsetup luksOpen --key-file=- "$ROOT_DEV" "$ROOT_DM_NAME" \
		|| fatal "cannot open root LUKS2 device $ROOT_DEV"
	inject_key | cryptsetup luksOpen --key-file=- "$UPDATE_DEV" "$UPDATE_DM_NAME" \
		|| fatal "cannot open update LUKS2 device $UPDATE_DEV"
fi

# Probe filesystem type on LUKS2 device before dm-verity
fstype=$(blkid -s TYPE -o value "/dev/mapper/$ROOT_DM_NAME" 2>/dev/null) \
	|| fatal "cannot detect root filesystem type"

# Set up dm-verity on the decrypted root device
setup_avb_verity "$ROOT_DM_NAME" "$VERITY_DM_NAME"
ROOT_BLOCK_DEV="/dev/mapper/$VERITY_DM_NAME"

mkdir -p "$ROOT_MNT"
# Mount encrypted root filesystem
klog "Mounting encrypted root filesystem $fstype on $ROOT_BLOCK_DEV..."
mount -t "$fstype" -o "$OPT_ROOT" "$ROOT_BLOCK_DEV" "$ROOT_MNT" \
	|| fatal "cannot mount root partition"

# Mount data partition
mount_data_luks "$DATA_DEV" "$DATA_DM_NAME" "data" "$ROOT_MNT$DATA_MNT" "$OPT_PART"

# Mount backups partition
mount_data_luks "$BACKUPS_DEV" "$BACKUPS_DM_NAME" "backups" "$ROOT_MNT$BACKUPS_MNT" "$OPT_PART"

# Clear cached key
unset ENC_KEY_HEX

mount -t vfat -o $OPT_PART $BOOT_DEV "$ROOT_MNT$BOOT_MNT" \
	|| fatal "cannot mount boot device $BOOT_DEV"
mount -t vfat -o $OPT_PART $BOOTUPDATE_DEV "$ROOT_MNT$BOOTUPDATE_MNT" \
	|| fatal "cannot mount boot update device $BOOTUPDATE_DEV"

# Derive Machine ID from HW_SERIAL
MACHINE_ID="$(tr -d '\0\n' < "$HW_SERIAL" | sha256sum | cut -c1-32)"

# Setup IMA/EVM
setup_integrity

# Switch to real root
klog "Switch to real root..."
exec switch_root $ROOT_MNT $INIT --machine-id="$MACHINE_ID" \
	|| fatal "cannot switch_root to real root"
