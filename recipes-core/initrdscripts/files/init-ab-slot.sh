#!/usr/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# A/B boot slot detection from device tree

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
	BLOBS_DEV="/dev/${BASE_DEV}${SEP}${BLOBS_PART}"
	DATA_DEV="/dev/${BASE_DEV}${SEP}${DATA_PART}"
}
