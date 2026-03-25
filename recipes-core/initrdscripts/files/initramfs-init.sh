#!/usr/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# initramfs init script:
#   mount_early_fs   - Mount devtmpfs, tmpfs, proc, sysfs, securityfs
#   get_boot_slot    - Detect A/B boot slot from device tree
#   inject_key       - Derive LUKS key from OTP HMAC or serial fallback
#   encrypt_rootfs   - First-boot rootfs encryption
#   mount_data_luks  - First-boot data partitions encryption
#   setup_integrity  - Import IMA/EVM keys and load secure boot policy
#   switch_root      - Switch to the real root filesystem
#

#set -x

export PATH=$PATH:/sbin:/usr/sbin

BOOT_DEV=""
ROOT_DEV=""
UPDATE_DEV=""
DATA_DEV=""
BACKUPS_DEV=""

ROOT_DM_NAME="root"
UPDATE_DM_NAME="update"
DATA_DM_NAME="data"
BACKUPS_DM_NAME="backups"

ROOT_MNT="/root"
BOOT_MNT="/boot"
DATA_MNT="/var/data"
BACKUPS_MNT="/var/backups"

OPT_ROOT="ro,noatime"
OPT_PART="noexec,nodev,nosuid"

IMA_POLICY="/etc/ima/ima-policy"
IMA_X509="/etc/keys/x509_ima.der"
EVM_X509="/etc/keys/x509_evm.der"
IMA_MANIFEST="/etc/ima/ima-signatures.manifest"
EVM_MANIFEST="/etc/ima/evm-signatures.manifest"

BOOT_SLOT="/proc/device-tree/chosen/bootloader/partition"
BOOT_MODE="/proc/device-tree/chosen/bootloader/boot-mode"

HW_SERIAL="/proc/device-tree/serial-number"
CID=""

ENC_KEY_HEX=""
MACHINE_ID=""

# Partition numbers for A/B slots, data and backups
# following wic configuration in rpi-secure.wks
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

# Init
INIT="/sbin/init"

fatal() {

	echo "FATAL: $1" >&2
	reboot -f
	#sh
}

klog() {

	echo $@
    echo "Initramfs: $@" > /dev/kmsg
}

hex2bin() {

	printf '%b' "$(echo "$1" | sed 's/../\\x&/g')"
}

mount_early_fs() {

	mount -t devtmpfs none /dev
	mount -t tmpfs tmp /tmp
	mount -t proc proc /proc
	mount -t sysfs sysfs /sys
	mount -t securityfs securityfs /sys/kernel/security
}

get_boot_slot() {

	if [ ! -e "$BOOT_SLOT" ] || [ ! -e "$BOOT_MODE" ]; then
		fatal "Boot slot DT nodes not available"
	fi

	mode_hex=$(hexdump -v -e '/1 "%02x"' "$BOOT_MODE" 2>/dev/null || true)
	case "$mode_hex" in
		00000001) BASE_DEV="mmcblk0" ;;
		00000004) BASE_DEV="sda" ;;
		00000006) BASE_DEV="nvme0n1" ;;
		*)		fatal "Unknown boot mode: $mode_hex" ;;
	esac

	# Partition separator: 'p' for mmcblk/nvme empty for sd
	case "$BASE_DEV" in
		sd*) SEP="" ;;
		*)	SEP="p" ;;
	esac

	boot_hex=$(hexdump -v -e '/1 "%02x"' "$BOOT_SLOT" 2>/dev/null || true)
	[ -n "$boot_hex" ] || {
		fatal "Failed to read boot slot from $BOOT_SLOT"
	}
	case "$boot_hex" in
		00000002)
			klog "Boot Slot A"
			BOOT_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_A}"
			ROOT_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_A}"
			UPDATE_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_B}"
			;;
		00000003)
			klog "Boot Slot B"
			BOOT_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_B}"
			ROOT_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_B}"
			UPDATE_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_A}"
			;;
		*) fatal "Unknown boot slot: $boot_hex" ;;
	esac

	DATA_DEV="/dev/${BASE_DEV}${SEP}${DATA_PART}"
	BACKUPS_DEV="/dev/${BASE_DEV}${SEP}${BACKUPS_PART}"
}

await_blockdev() {

	i=0
	while [ $i -lt $TIMEOUT ]; do
		if [ -b "$1" ] ; then
				break;
		fi
		i=$((i + 1))
		sleep 0.1
	done
	if [ $i -eq $TIMEOUT ]; then
		fatal "Timeout waiting for $1"
	fi
}

# Restore IMA/EVM xattrs from build-time manifest
# cpio newc format does not preserve xattrs so we re-apply them
# Usage: restore_ima_evm_signatures <manifest> <xattr> <target_root> [file]
#   If [file] is given, only restore that single file's signature
restore_ima_evm_signatures() {

	manifest="$1"
	xattr="$2"
	target="$3"
	single="$4"

	[ -f "$manifest" ] || return 0

	if [ -n "$single" ]; then
		sig=$(grep "^${single} " "$manifest" | cut -d' ' -f2)
		[ -n "$sig" ] && [ -e "${target}${single}" ] && \
			setfattr -n "$xattr" -v "${sig#*:}" "${target}${single}" 2>/dev/null
		return 0
	fi

	while read filepath sig; do
		[ -e "${target}${filepath}" ] || continue
		setfattr -n "$xattr" -v "${sig#*:}" "${target}${filepath}" 2>/dev/null
	done < "$manifest"
}

setup_integrity() {

	root_dev="$1"

	# Restore IMA/EVM signatures on initramfs file path so that :
	# switch_root binary does not break signature verification
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/bin/busybox.nosuid"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/bin/busybox.nosuid"
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/ld-linux-aarch64.so.1"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/ld-linux-aarch64.so.1"  
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/libm.so.6"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/libm.so.6"
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/libc.so.6"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/libc.so.6"

	# Import IMA/EVM X509
	if [ ! -f "$IMA_X509" ] || [ ! -f "$EVM_X509" ]; then
		fatal "IMA/EVM X509 certificates not found!"
	fi

	ima_id=$(keyctl newring _ima @u)
	evmctl import "$IMA_X509" $ima_id > /dev/null 2>&1

	evm_id=$(keyctl newring _evm @u)
	evmctl import "$EVM_X509" $evm_id > /dev/null 2>&1

	# Load IMA policy
	if [ ! -f "$IMA_POLICY" ]; then
		fatal "IMA policy not found!"
	fi

	# Get root filesystem UUID
	FSUUID=$(blkid $root_dev -s UUID -o value)
	if [ -z "$FSUUID" ]; then
		fatal "cannot get filesystem UUID for $root_dev"
	fi

	# Replace placeholder in IMA policy before loading it
	sed "s|__FSUUID__|$FSUUID|g" "$IMA_POLICY"       \
		 > /sys/kernel/security/integrity/ima/policy \
		|| fatal "cannot load IMA policy"

	# Enable EVM in signature verification mode only 
	# and lock the configuration to prevent changes at runtime
	echo "0x80000002" > /sys/kernel/security/integrity/evm/evm
}

# Derive LUKS encryption key from secure storage:
# Uses rpi-fw-crypto HMAC-SHA256 with the OTP device key
# The HMAC input is the storage device CID (if available) which
# binds the key to the specific eMMC/SD/NVMe hardware preventing
# cloned disk images from being decrypted
# Falls back to HW_SERIAL if CID is not available on USB boot
# Falls back to sha256(serial) if OTP key is not provisioned.
#
# To provision an OTP key (one-time irreversible to fuses):
#   $ rpi-fw-crypto genkey --key-id 1 --alg ec
# then lock raw key readout in config.txt:
#   lock_device_private_key=1
#
# The derived key hex is cached in ENC_KEY_HEX so the expensive
# derivation (OTP HMAC / block-device-id) runs only once per boot.
derive_key() {

	[ -e "$HW_SERIAL" ] || fatal "Hardware serial not found at $HW_SERIAL"

	CID=$(block-device-id "/dev/$BASE_DEV" 2>/dev/null) \
		|| klog "cannot read CID from /dev/$BASE_DEV"

	# Try hardware-bound key via OTP HMAC
	if rpi-fw-crypto pubkey --key-id "$OTP_KEY_ID" --out /dev/null 2>/dev/null; then
		if [ -n "$CID" ]; then
			ENC_KEY_HEX=$(printf '%s' "$CID" | rpi-fw-crypto hmac --in /proc/self/fd/0 --key-id "$OTP_KEY_ID" --outform hex 2>/dev/null)
		else
			ENC_KEY_HEX=$(rpi-fw-crypto hmac --in "$HW_SERIAL" --key-id "$OTP_KEY_ID" --outform hex 2>/dev/null)
		fi
		if [ -n "$ENC_KEY_HEX" ]; then
			return 0
		fi
		klog "WARNING: OTP HMAC failed, falling back to serial-based key" >&2
	else
		klog "WARNING: OTP key not provisioned, falling back to serial-based key" >&2
	fi

	if [ -n "$CID" ]; then
		ENC_KEY_HEX=$(printf '%s' "$CID" | sha256sum | cut -d' ' -f1)
	else
		ENC_KEY_HEX=$(tr -d '\0' < "$HW_SERIAL" | sha256sum | cut -d' ' -f1)
	fi
}

inject_key() {

	hex2bin "$ENC_KEY_HEX"
}

#############################################################################
# Encrypt rootfs on first boot using the update partition.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: This operation is NOT power-safe. 
# Power loss mid-migration can leave both root partitions unrecoverable
# should ideally be performed during manufacturing or 
# initial provisioning and not in the field
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Flow:
#   Format root partition as LUKS, copy from update (plain) into it
#   then format update partition as LUKS
#############################################################################
encrypt_rootfs() {

	root_dev="$1"
	update_dev="$2"
	root_dm="$3"
	update_dm="$4"
	luks_opts="--key-size 256"

	klog "First-boot rootfs encryption: migrating plain rootfs to dm-crypt LUKS..."
	enc_start=$(date +%s)

	# Detect filesystem type
	fstype=$(blkid -s TYPE -o value "$update_dev" 2>/dev/null) \
		|| fatal "cannot detect root filesystem type"
	klog "Update partition filesystem: $fstype"

	# Shrink ext4 to minimum before copying to save space in LUKS header
	if [ "$fstype" = "ext4" ]; then
		klog "Shrinking ext4 to minimum..."
		e2fsck -fy "$update_dev" > /dev/null 2>&1
		resize2fs -M "$update_dev" > /dev/null 2>&1
	fi

	# Format root partition as LUKS, copy from update
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$root_dev" \
		|| fatal "cannot format root $root_dev as LUKS"
	inject_key | cryptsetup luksOpen --key-file=- "$root_dev" "$root_dm" \
		|| fatal "cannot open root LUKS $root_dev"

	# Copy filesystem from update partition (already pre-built by wic)
	klog "Copying $fstype filesystem from $update_dev to encrypted root volume..."
	dd if="$update_dev" of="/dev/mapper/$root_dm" bs=4M 2>/dev/null
	sync

	# Expand ext4 to fill entire LUKS root container
	if [ "$fstype" = "ext4" ]; then
		klog "Expanding ext4 to fill LUKS container..."
		e2fsck -fy "/dev/mapper/$root_dm" > /dev/null 2>&1
		resize2fs "/dev/mapper/$root_dm" > /dev/null 2>&1
	fi

	# Format update partition as LUKS
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$update_dev" \
		|| fatal "cannot format update $update_dev as LUKS"
	inject_key | cryptsetup luksOpen --key-file=- "$update_dev" "$update_dm" \
		|| fatal "cannot open update LUKS $update_dev"

	enc_end=$(date +%s)
	klog "Rootfs encryption complete in $((enc_end - enc_start))s"
}

# Mount a data partition with LUKS encryption.
# First boot: luksFormat + mkfs.ext4 + mount
# Normal boot: luksOpen + mount
# Usage: mount_data_luks <device> <dm_name> <label> <mountpoint> [mount_opts]
mount_data_luks() {

	dev="$1"
	dm_name="$2"
	label="$3"
	mnt="$4"
	mnt_opts="${5:-$OPT_PART}"
	luks_opts="--key-size 256"

	[ -n "$dev" ] || return 0
	[ -n "$DM_INTEGRITY" ] && luks_opts="$luks_opts --integrity $DM_INTEGRITY"

	if ! cryptsetup isLuks "$dev" 2>/dev/null; then
		fmt_start=$(date +%s)
		klog "Formatting $dev as LUKS2 for $dm_name..."
		inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$dev" \
			|| fatal "cannot format $dev as LUKS"
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS device $dev"
		mkfs.ext4 -L "$label" "/dev/mapper/$dm_name" > /dev/null 2>&1 \
			|| fatal "cannot create filesystem on $dm_name"
		fmt_end=$(date +%s)
		klog "LUKS+ext4 setup of $dev completed in $((fmt_end - fmt_start))s"
	else
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS device $dev"
	fi

	mkdir -p "$mnt"
	mount -o $mnt_opts -t ext4 "/dev/mapper/$dm_name" "$mnt" \
		|| fatal "cannot mount /dev/mapper/$dm_name on $mnt"
}

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

# Derive and cache the LUKS key once
derive_key

if ! cryptsetup isLuks "$ROOT_DEV" 2>/dev/null; then
	encrypt_rootfs "$ROOT_DEV" "$UPDATE_DEV" "$ROOT_DM_NAME" "$UPDATE_DM_NAME"
else
	inject_key | cryptsetup luksOpen --key-file=- "$ROOT_DEV" "$ROOT_DM_NAME" \
		|| fatal "cannot open root LUKS device $ROOT_DEV"
	inject_key | cryptsetup luksOpen --key-file=- "$UPDATE_DEV" "$UPDATE_DM_NAME" \
		|| fatal "cannot open update LUKS device $UPDATE_DEV"
fi

# Probe and validate root filesystem type
fstype=$(blkid -s TYPE -o value "/dev/mapper/$ROOT_DM_NAME" 2>/dev/null) \
	|| fatal "cannot detect root filesystem type"
mkdir -p "$ROOT_MNT"
# Mount encrypted root filesystem
mount -t "$fstype" -o "$OPT_ROOT" "/dev/mapper/$ROOT_DM_NAME" "$ROOT_MNT" \
	|| fatal "cannot mount root partition"

# Mount data partition
mount_data_luks "$DATA_DEV" "$DATA_DM_NAME" "data" "$ROOT_MNT$DATA_MNT" "$OPT_PART"

# Mount backups partition
mount_data_luks "$BACKUPS_DEV" "$BACKUPS_DM_NAME" "backups" "$ROOT_MNT$BACKUPS_MNT" "$OPT_PART"

# Clear cached key
unset ENC_KEY_HEX

mount -t vfat -o $OPT_PART $BOOT_DEV "$ROOT_MNT$BOOT_MNT" \
	|| fatal "cannot mount boot device $BOOT_DEV"


# Derive Machine ID from HW_SERIAL
MACHINE_ID="$(tr -d '\0\n' < "$HW_SERIAL" | sha256sum | cut -c1-32)"

# Setup IMA/EVM
setup_integrity "/dev/mapper/$ROOT_DM_NAME"

# Switch to real root
klog "Switch to real root..."
exec switch_root $ROOT_MNT $INIT --machine-id="$MACHINE_ID" \
	|| fatal "cannot switch_root to real root"
