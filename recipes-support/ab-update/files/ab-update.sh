#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions
#
# ab-update.sh: update the inactive A/B boot and root partitions
#
# Usage:
#   ab-update.sh -b <boot.img> -s <boot.sig> -r <rootfs.img>
#   ab-update.sh -b <boot.img> -s <boot.sig>
#   ab-update.sh -r <rootfs.img>
#   ab-update.sh -c
#
# The script detects the current active boot slot from the device tree,
# writes the provided images to the inactive (redundant) slot, and
# sets the tryboot flag so the firmware boots from the updated slot
# on the next reboot.
#
# The initramfs already opens both LUKS2 containers at boot:
#   /dev/mapper/root    active root slot
#   /dev/mapper/update  inactive root slot (update target)
# This script writes directly to the already-open dm device.
#

set -e

BOOT_SLOT_DT="/proc/device-tree/chosen/bootloader/partition"
BOOT_MODE_DT="/proc/device-tree/chosen/bootloader/boot-mode"

BOOT_SLOT_A=2
BOOT_SLOT_B=3

# The initramfs opens the inactive root LUKS2 as /dev/mapper/update
UPDATE_DM="/dev/mapper/update"

# autoboot.txt on the boot selector partition (mounted at /boot by initramfs)
AUTOBOOT_TXT="/boot/autoboot.txt"

BOOT_IMG=""
BOOT_SIG=""
ROOTFS_IMG=""
CONFIRM=0

die() {

    echo "ERROR: $1" >&2
    exit 1
}

usage() {

    echo "Usage: $0 [-b <boot.img>] [-s <boot.sig>] [-r <rootfs.img>] [-c]"
    echo "  -b <boot.img>    Boot image to write to inactive boot partition"
    echo "  -s <boot.sig>    Boot signature to write to inactive boot partition"
    echo "  -r <rootfs.img>  Rootfs image to write to inactive root partition"
    echo "  -c               Confirm: make the current tryboot slot the new default"
    echo "At least one of -b, -r, or -c must be specified."
    exit 1
}

detect_slot() {

    [ -e "$BOOT_SLOT_DT" ] || die "Boot slot DT node not available"
    [ -e "$BOOT_MODE_DT" ] || die "Boot mode DT node not available"

    mode_hex=$(hexdump -v -e '/1 "%02x"' "$BOOT_MODE_DT" 2>/dev/null) || true
    case "$mode_hex" in
        00000001) BASE_DEV="mmcblk0" ;;
        00000004) BASE_DEV="sda" ;;
        00000006) BASE_DEV="nvme0n1" ;;
        *)        die "Unknown boot mode: $mode_hex" ;;
    esac

    case "$BASE_DEV" in
        sd*) SEP="" ;;
        *)   SEP="p" ;;
    esac

    boot_hex=$(hexdump -v -e '/1 "%02x"' "$BOOT_SLOT_DT" 2>/dev/null) || true
    [ -n "$boot_hex" ] || die "Failed to read boot slot"

    case "$boot_hex" in
        00000002)
            ACTIVE_SLOT="A"
            ACTIVE_PART=$BOOT_SLOT_A
            INACTIVE_BOOT="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_B}"
            INACTIVE_PART=$BOOT_SLOT_B
            ;;
        00000003)
            ACTIVE_SLOT="B"
            ACTIVE_PART=$BOOT_SLOT_B
            INACTIVE_BOOT="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_A}"
            INACTIVE_PART=$BOOT_SLOT_A
            ;;
        *) die "Unknown boot slot: $boot_hex" ;;
    esac
}

update_boot() {

    img="$1"
    mnt=$(mktemp -d) || die "Failed to create temp mount point"

    echo "Updating boot image on inactive partition $INACTIVE_BOOT ..."
    mount -t vfat "$INACTIVE_BOOT" "$mnt" \
        || die "Failed to mount $INACTIVE_BOOT"

    cp "$img" "$mnt/tryboot.img" \
        || { umount "$mnt"; rmdir "$mnt"; die "Failed to copy tryboot.img to $INACTIVE_BOOT"; }

    if [ -n "$BOOT_SIG" ]; then
        cp "$BOOT_SIG" "$mnt/tryboot.sig" \
            || { umount "$mnt"; rmdir "$mnt"; die "Failed to copy tryboot.sig to $INACTIVE_BOOT"; }
    fi

    sync
    umount "$mnt"
    rmdir "$mnt"
    echo "Boot partition updated."
}

update_root() {

    img="$1"

    [ -b "$UPDATE_DM" ] || die "Update dm device $UPDATE_DM not available (LUKS not opened by initramfs?)"

    echo "Writing rootfs image to $UPDATE_DM ..."
    case "$img" in
        *.gz)  gzip  -dc "$img" ;;
        *.xz)  xz    -dc "$img" ;;
        *.zst) zstd  -dc "$img" ;;
        *.bz2) bzip2 -dc "$img" ;;
        *)     cat "$img" ;;
    esac | dd of="$UPDATE_DM" bs=4M conv=fsync 2>/dev/null \
        || die "Failed to write rootfs to $UPDATE_DM"
    echo "Root partition updated."
}

# Make the current active slot the permanent default by:
# 1. Renaming tryboot.img -> boot.img on the active boot partition
# 2. Rewriting autoboot.txt on the boot selector partition
confirm_update() {

    echo "Confirming slot $ACTIVE_SLOT as permanent default..."

    # Rename tryboot files to boot on the active boot partition
    active_boot="/dev/${BASE_DEV}${SEP}${ACTIVE_PART}"
    mnt=$(mktemp -d) || die "Failed to create temp mount point"

    mount -t vfat "$active_boot" "$mnt" \
        || die "Failed to mount $active_boot"

    if [ -f "$mnt/tryboot.img" ]; then
        mv "$mnt/tryboot.img" "$mnt/boot.img" \
            || { umount "$mnt"; rmdir "$mnt"; die "Failed to rename tryboot.img"; }
    fi
    if [ -f "$mnt/tryboot.sig" ]; then
        mv "$mnt/tryboot.sig" "$mnt/boot.sig" \
            || { umount "$mnt"; rmdir "$mnt"; die "Failed to rename tryboot.sig"; }
    fi

    sync
    umount "$mnt"
    rmdir "$mnt"

    # Update autoboot.txt
    tmpfile=$(mktemp) || die "Failed to create temp file"

    cat > "$tmpfile" <<EOF
[tryboot]
boot_partition=$INACTIVE_PART

[all]
boot_partition=$ACTIVE_PART
EOF

    cp "$tmpfile" "$AUTOBOOT_TXT" || die "Failed to update $AUTOBOOT_TXT"
    sync
    rm -f "$tmpfile"
    echo "Slot $ACTIVE_SLOT is now the permanent default."
}

set_tryboot() {

    echo "Update complete. Reboot into the updated slot with:"
    echo "  reboot '0 tryboot'"
    echo "After verifying, run '$0 -c' to make it permanent."
}

while getopts "b:s:r:ch" opt; do
    case "$opt" in
        b) BOOT_IMG="$OPTARG" ;;
        s) BOOT_SIG="$OPTARG" ;;
        r) ROOTFS_IMG="$OPTARG" ;;
        c) CONFIRM=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$BOOT_IMG" ] && [ -z "$ROOTFS_IMG" ] && [ "$CONFIRM" -eq 0 ]; then
    usage
fi

if [ -n "$BOOT_IMG" ] && [ ! -f "$BOOT_IMG" ]; then
    die "Boot image not found: $BOOT_IMG"
fi

if [ -n "$BOOT_SIG" ] && [ ! -f "$BOOT_SIG" ]; then
    die "Boot signature not found: $BOOT_SIG"
fi

if [ -n "$ROOTFS_IMG" ] && [ ! -f "$ROOTFS_IMG" ]; then
    die "Rootfs image not found: $ROOTFS_IMG"
fi


detect_slot
echo "Active slot: $ACTIVE_SLOT"
echo "Inactive boot partition: $INACTIVE_BOOT"
echo "Inactive root partition: $UPDATE_DM"

if [ -n "$BOOT_IMG" ]; then
    update_boot "$BOOT_IMG"
fi

if [ -n "$ROOTFS_IMG" ]; then
    update_root "$ROOTFS_IMG"
fi

if [ "$CONFIRM" -eq 1 ]; then
    confirm_update
else
    set_tryboot
fi
