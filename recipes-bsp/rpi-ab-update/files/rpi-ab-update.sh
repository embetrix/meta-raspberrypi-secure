#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions
#
# rpi-ab-update.sh: update the inactive A/B boot and root partitions
#
# Usage:
#   rpi-ab-update.sh -b <boot.img> -s <boot.sig> -r <rootfs.img>
#   rpi-ab-update.sh -c
#   rpi-ab-update.sh -t
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
TRYBOOT_DT="/proc/device-tree/chosen/bootloader/tryboot"

BOOT_SLOT_A=2
BOOT_SLOT_B=3

# The initramfs opens the inactive root LUKS2 as /dev/mapper/update
UPDATE_DM="/dev/mapper/update"

# Boot partitions mounted by initramfs
BOOT_MNT="/boot"
BOOT_ACTIVE_MNT="/boot-active"
BOOT_UPDATE_MNT="/boot-update"
AUTOBOOT_TXT="${BOOT_MNT}/autoboot.txt"

BOOT_IMG=""
BOOT_SIG=""
ROOTFS_IMG=""
CONFIRM=0
STATUS=0

die() {

    echo "ERROR: $1" >&2
    exit 1
}

usage() {

    echo "Usage: $0 -b <boot.img> -s <boot.sig> -r <rootfs.img>"
    echo "       $0 -c"
    echo "       $0 -t"
    echo "  -b <boot.img>    Boot image to write to inactive boot partition"
    echo "  -s <boot.sig>    Boot signature to write to inactive boot partition"
    echo "  -r <rootfs.img>  Rootfs image to write to inactive root partition"
    echo "  -c               Confirm: make the current tryboot slot the new default"
    echo "  -t               Check if currently running in tryboot mode"
    exit 1
}

detect_slot() {

    [ -e "$BOOT_SLOT_DT" ] || die "Boot slot DT node not available"

    boot_hex=$(hexdump -v -e '/1 "%02x"' "$BOOT_SLOT_DT" 2>/dev/null) || true
    [ -n "$boot_hex" ] || die "Failed to read boot slot"

    case "$boot_hex" in
        00000002)
            ACTIVE_SLOT="A"
            ACTIVE_PART=$BOOT_SLOT_A
            INACTIVE_PART=$BOOT_SLOT_B
            ;;
        00000003)
            ACTIVE_SLOT="B"
            ACTIVE_PART=$BOOT_SLOT_B
            INACTIVE_PART=$BOOT_SLOT_A
            ;;
        *) die "Unknown boot slot: $boot_hex" ;;
    esac
}

# Check if the system booted via tryboot using the firmware DT node.
# Returns 0 if tryboot, 1 if normal boot.
is_tryboot() {

    [ -e "$TRYBOOT_DT" ] || die "Tryboot DT node not available"

    tryboot_hex=$(hexdump -v -e '/1 "%02x"' "$TRYBOOT_DT" 2>/dev/null) || true
    [ -n "$tryboot_hex" ] || die "Failed to read tryboot status"

    [ "$tryboot_hex" = "00000001" ]
}

update_boot() {

    img="$1"

    echo "Updating boot image on inactive partition at $BOOT_UPDATE_MNT ..."

    cp "$img" "$BOOT_UPDATE_MNT/tryboot.img" \
        || die "Failed to copy tryboot.img to $BOOT_UPDATE_MNT"
    cp "$img" "$BOOT_UPDATE_MNT/boot.img" \
        || die "Failed to copy boot.img to $BOOT_UPDATE_MNT"

    if [ -n "$BOOT_SIG" ]; then
        cp "$BOOT_SIG" "$BOOT_UPDATE_MNT/tryboot.sig" \
            || die "Failed to copy tryboot.sig to $BOOT_UPDATE_MNT"
        cp "$BOOT_SIG" "$BOOT_UPDATE_MNT/boot.sig" \
            || die "Failed to copy boot.sig to $BOOT_UPDATE_MNT"
    fi

    sync
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

# Make the current active slot the permanent default by rewriting
# autoboot.txt on the boot selector partition (partition 1).
# Both boot.img and tryboot.img were written during update, so no
# rename is needed — only the tiny autoboot.txt switch.
confirm_update() {

    echo "Confirming slot $ACTIVE_SLOT as permanent default..."

    # Update autoboot.txt
    tmpfile=$(mktemp) || die "Failed to create temp file"

    cat > "$tmpfile" <<EOF
[all]
boot_partition=$ACTIVE_PART

[tryboot]
boot_partition=$INACTIVE_PART
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

while getopts "b:s:r:cth" opt; do
    case "$opt" in
        b) BOOT_IMG="$OPTARG" ;;
        s) BOOT_SIG="$OPTARG" ;;
        r) ROOTFS_IMG="$OPTARG" ;;
        c) CONFIRM=1 ;;
        t) STATUS=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ "$CONFIRM" -eq 0 ] && [ "$STATUS" -eq 0 ]; then
    if [ -z "$BOOT_IMG" ] || [ -z "$BOOT_SIG" ] || [ -z "$ROOTFS_IMG" ]; then
        usage
    fi
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
echo "  Active partition: $ACTIVE_PART  Inactive partition: $INACTIVE_PART"
echo "  autoboot.txt: $(cat "$AUTOBOOT_TXT" 2>/dev/null | tr '\n' ' ')"

if [ "$STATUS" -eq 1 ]; then
    if is_tryboot; then
        echo "Tryboot active (slot $ACTIVE_SLOT). Run '$0 -c' to confirm."
    else
        echo "Normal boot (slot $ACTIVE_SLOT)."
    fi
    exit 0
fi

if [ -n "$BOOT_IMG" ]; then
    update_boot "$BOOT_IMG"
fi

if [ -n "$ROOTFS_IMG" ]; then
    update_root "$ROOTFS_IMG"
fi

if [ "$CONFIRM" -eq 1 ]; then
    is_tryboot || die "Not in tryboot mode, nothing to confirm"
    confirm_update
else
    set_tryboot
fi
