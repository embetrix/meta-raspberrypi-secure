#!/usr/bin/sh
# SPDX-License-Identifier: MIT
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# rpi secure initramfs init script:
#   mount_early_fs      - Mount devtmpfs, tmpfs, proc, sysfs, securityfs
#   get_boot_slot       - Detect A/B boot slot from device tree
#   encrypt_rootfs      - First-boot rootfs encryption (plain to dm-crypt)
#   setup_avb_verity    - AVB signature verification and dm-verity setup
#   mount_dmcrypt_data  - First-boot data partitions encryption
#   setup_evm_integrity - Setup EVM mode
#   switch_root         - Switch to the real root filesystem
#

#set -x
umask 077
export PATH=$PATH:/sbin:/usr/sbin

BOOT_DEV=""
BOOTACTIVE_DEV=""
BOOTUPDATE_DEV=""
BLOBS_DEV=""
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
BLOBS_MNT="/blobs"
DATA_MNT="/var/data"
BACKUPS_MNT="/var/backups"

OPT_ROOT="ro,noatime"
OPT_PART="noexec,nodev,nosuid,iversion"

KMK_BLOB="$BLOBS_MNT/kmk.blob"
ENC_KEY_BLOB="$BLOBS_MNT/enc-key.blob"
EVM_KEY_BLOB="$BLOBS_MNT/evm-key.blob"
KEY_SZ=32

BOOT_SLOT="/proc/device-tree/chosen/bootloader/partition"
BOOT_MODE="/proc/device-tree/chosen/bootloader/boot-mode"

HW_SERIAL="/proc/device-tree/serial-number"

MACHINE_ID=""

# Partition numbers for A/B slots, data and backups
# following wic configuration in rpi-secure.wks
BOOT=1
BOOT_SLOT_A=2
BOOT_SLOT_B=3
BLOBS_PART=4
ROOT_SLOT_A=5
ROOT_SLOT_B=6
DATA_PART=7
BACKUPS_PART=8

TIMEOUT=40

OTP_KEY_ID=1

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

# Mount blobs partition containing encryption keys KMK and blobs
fsck.ext4 -y "$BLOBS_DEV" || klog "fsck.ext4 on $BLOBS_DEV returned $?"
mount -t ext4 -o $OPT_PART $BLOBS_DEV "$BLOBS_MNT" \
	|| fatal "cannot mount blobs device $BLOBS_DEV"

# Set up encrypted keys in kernel keyring
setup_encrypted_keys

# Unmount blobs partition after loading keys
umount "$BLOBS_MNT"

# dm-crypt and EVM use request_key() which searches the session keyring,
# not the user keyring where the keys were added
keyctl link @us @s

# Always open root as dm-crypt first.
# First boot : decrypted content is garbage (no rootfs yet) will lead to blkid fails
# Normal boot: decrypted content is valid erofs+AVB will lead to blkid succeess
setup_dmcrypt "$ROOT_DEV" "$ROOT_DM_NAME"

if ! blkid -s TYPE "/dev/mapper/$ROOT_DM_NAME" >/dev/null 2>&1; then
	encrypt_rootfs "$ROOT_DM_NAME" "$UPDATE_DEV" "$UPDATE_DM_NAME"
else
	setup_dmcrypt "$UPDATE_DEV" "$UPDATE_DM_NAME"
fi

# Probe filesystem type on dm-crypt device before dm-verity
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
mount_dmcrypt_data "$DATA_DEV" "$DATA_DM_NAME" "data" "$ROOT_MNT$DATA_MNT" "$OPT_PART"

# Mount backups partition
mount_dmcrypt_data "$BACKUPS_DEV" "$BACKUPS_DM_NAME" "backups" "$ROOT_MNT$BACKUPS_MNT" "$OPT_PART"

fsck.vfat -y -w "$BOOT_DEV" || klog "fsck on $BOOT_DEV returned $?"
mount -t vfat -o $OPT_PART $BOOT_DEV "$ROOT_MNT$BOOT_MNT" \
	|| fatal "cannot mount boot device $BOOT_DEV"

fsck.vfat -y -w "$BOOTUPDATE_DEV" || klog "fsck on $BOOTUPDATE_DEV returned $?"
mount -t vfat -o $OPT_PART $BOOTUPDATE_DEV "$ROOT_MNT$BOOTUPDATE_MNT" \
	|| fatal "cannot mount boot update device $BOOTUPDATE_DEV"

# Derive Machine ID from HW_SERIAL
MACHINE_ID="$(tr -d '\0\n' < "$HW_SERIAL" | sha256sum | cut -c1-32)"

# Setup EVM
setup_evm_integrity

# Switch to real root
klog "Switch to real root..."
exec switch_root $ROOT_MNT $INIT --machine-id="$MACHINE_ID" \
	|| fatal "cannot switch_root to real root"
