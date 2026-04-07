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
			BOOTACTIVE_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_A}"
			BOOTUPDATE_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_B}"
			ROOT_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_A}"
			UPDATE_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_B}"
			;;
		00000003)
			klog "Boot Slot B"
			BOOTACTIVE_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_B}"
			BOOTUPDATE_DEV="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_A}"
			ROOT_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_B}"
			UPDATE_DEV="/dev/${BASE_DEV}${SEP}${ROOT_SLOT_A}"
			;;
		*) fatal "Unknown boot slot: $boot_hex" ;;
	esac
	BOOT_DEV="/dev/${BASE_DEV}${SEP}${BOOT}"
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

	klog "Setting up IMA/EVM Integrity..."

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

	cat "$IMA_POLICY" \
		 > /sys/kernel/security/integrity/ima/policy \
		|| fatal "cannot load IMA policy"

	# Enable EVM in signature verification mode only 
	# and lock the configuration to prevent changes at runtime
	echo "0x80000002" > /sys/kernel/security/integrity/evm/evm
}

# Derive LUKS2 encryption key from secure storage:
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
# WARNING: This operation is NOT power-safe
# Power loss mid-migration can leave both root partitions unrecoverable
# should ideally be performed during manufacturing or 
# initial provisioning and not in the field
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Flow:
#   Format root partition as LUKS2, copy from update (plain) into it
#   then format update partition as LUKS2
#############################################################################
encrypt_rootfs() {

	root_dev="$1"
	update_dev="$2"
	root_dm="$3"
	update_dm="$4"
	luks_opts="--type luks2 --key-size 256"

	klog "First-boot rootfs encryption: migrating plain rootfs to dm-crypt LUKS2..."
	enc_start=$(date +%s)

	# Detect filesystem type
	fstype=$(blkid -s TYPE -o value "$update_dev" 2>/dev/null) \
		|| fatal "cannot detect root filesystem type"
	klog "Update partition filesystem: $fstype"

	# Format root partition as LUKS2, copy from update
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$root_dev" \
		|| fatal "cannot format root $root_dev as LUKS2"
	inject_key | cryptsetup luksOpen --key-file=- "$root_dev" "$root_dm" \
		|| fatal "cannot open root LUKS2 $root_dev"

	# Copy the entire AVB image (filesystem + hashtree + footer)
	# from the update partition into the LUKS2 container.
	# Do NOT shrink or expand the filesystem the AVB hashtree
	# must remain intact for dm-verity verification.
	klog "Copying image from $update_dev to encrypted root volume..."
	dd if="$update_dev" of="/dev/mapper/$root_dm" bs=4M 2>/dev/null
	sync

	# Format update partition as LUKS2
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$update_dev" \
		|| fatal "cannot format update $update_dev as LUKS2"
	inject_key | cryptsetup luksOpen --key-file=- "$update_dev" "$update_dm" \
		|| fatal "cannot open update LUKS2 $update_dev"

	enc_end=$(date +%s)
	klog "Rootfs encryption complete in $((enc_end - enc_start))s"
}

# Verify AVB signature and set up dm-verity on the decrypted root device.
# The AVB footer (with hashtree) lives inside the LUKS2 container.
# Usage: setup_avb_verity <luks_dm_name> <verity_dm_name>
setup_avb_verity() {

	luks_dev="/dev/mapper/$1"
	verity_name="$2"

	if [ ! -f "$AVB_PUBKEY" ]; then
		fatal "AVB public key not found at $AVB_PUBKEY"
	fi

	klog "Verifying AVB signature on $luks_dev..."
	dm_table=$(avb_verify --dm-table -d "$luks_dev" -k "$AVB_PUBKEY") \
		|| fatal "AVB verification failed on $luks_dev"

	klog "Setting up dm-verity as $verity_name..."
	echo "$dm_table" | dmsetup create --readonly "$verity_name" \
		|| fatal "cannot create dm-verity device $verity_name"

	# No udev in initramfs so create the device node manually
	dmsetup mknodes "$verity_name"

	klog "dm-verity $verity_name active on $luks_dev"
}

# Mount a data partition with LUKS2 encryption.
# First boot: luksFormat + mkfs.ext4 + mount
# Normal boot: luksOpen + mount
# Usage: mount_data_luks <device> <dm_name> <label> <mountpoint> [mount_opts]
mount_data_luks() {

	dev="$1"
	dm_name="$2"
	label="$3"
	mnt="$4"
	mnt_opts="${5:-$OPT_PART}"
	luks_opts="--type luks2 --key-size 256"

	[ -n "$dev" ] || return 0
	[ -n "$DM_INTEGRITY" ] && luks_opts="$luks_opts --integrity $DM_INTEGRITY"

	if ! cryptsetup isLuks "$dev" 2>/dev/null; then
		fmt_start=$(date +%s)
		klog "Formatting $dev as LUKS2 for $dm_name..."
		inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$dev" \
			|| fatal "cannot format $dev as LUKS2"
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS2 device $dev"
		mkfs.ext4 -L "$label" "/dev/mapper/$dm_name" > /dev/null 2>&1 \
			|| fatal "cannot create filesystem on $dm_name"
		fmt_end=$(date +%s)
		klog "LUKS2+ext4 setup of $dev completed in $((fmt_end - fmt_start))s"
	else
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS2 device $dev"
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
