#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions
#
# ab-update.sh — Update the inactive A/B boot and root partitions
#
# Usage:
#   ab-update.sh -b <boot.img> -r <rootfs.img>
#   ab-update.sh -b <boot.img>
#   ab-update.sh -r <rootfs.img>
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

BOOT_IMG=""
ROOTFS_IMG=""

die() {

    echo "ERROR: $1" >&2
    exit 1
}

usage() {

    echo "Usage: $0 -b <boot.img> -r <rootfs.img>"
    echo "  -b <boot.img>    Boot image to write to inactive boot partition"
    echo "  -r <rootfs.img>  Rootfs image to write to inactive root partition"
    echo "At least one of -b or -r must be specified."
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
            INACTIVE_BOOT="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_B}"
            ;;
        00000003)
            ACTIVE_SLOT="B"
            INACTIVE_BOOT="/dev/${BASE_DEV}${SEP}${BOOT_SLOT_A}"
            ;;
        *) die "Unknown boot slot: $boot_hex" ;;
    esac
}

update_boot() {

    local img="$1"
    local mnt
    mnt=$(mktemp -d) || die "Failed to create temp mount point"

    echo "Updating boot image on inactive partition $INACTIVE_BOOT ..."
    mount -t vfat "$INACTIVE_BOOT" "$mnt" \
        || die "Failed to mount $INACTIVE_BOOT"

    cp "$img" "$mnt/boot.img" \
        || { umount "$mnt"; rmdir "$mnt"; die "Failed to copy boot image to $INACTIVE_BOOT"; }

    sync
    umount "$mnt"
    rmdir "$mnt"
    echo "Boot partition updated."
}

update_root() {

    local img="$1"

    [ -b "$UPDATE_DM" ] || die "Update dm device $UPDATE_DM not available (LUKS not opened by initramfs?)"

    echo "Writing rootfs image to $UPDATE_DM ..."
    dd if="$img" of="$UPDATE_DM" bs=4M conv=fsync 2>/dev/null \
        || die "Failed to write rootfs to $UPDATE_DM"
    echo "Root partition updated."
}

set_tryboot() {

    echo "Update complete. Reboot into the updated slot with:"
    echo "  reboot '0 tryboot'"
}

while getopts "b:r:h" opt; do
    case "$opt" in
        b) BOOT_IMG="$OPTARG" ;;
        r) ROOTFS_IMG="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$BOOT_IMG" ] && [ -z "$ROOTFS_IMG" ]; then
    usage
fi

if [ -n "$BOOT_IMG" ] && [ ! -f "$BOOT_IMG" ]; then
    die "Boot image not found: $BOOT_IMG"
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

set_tryboot
