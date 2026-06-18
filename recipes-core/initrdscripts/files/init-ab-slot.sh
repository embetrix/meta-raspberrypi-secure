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

    # Symlink boot device to a known location
    ln -sf /dev/${BASE_DEV} /dev/bootdev
}

# Echo the other A/B boot partition number.
_other_boot_part() {

	case "$1" in
		"$BOOT_SLOT_A") echo "$BOOT_SLOT_B" ;;
		"$BOOT_SLOT_B") echo "$BOOT_SLOT_A" ;;
	esac
}

# Validate autoboot.txt: tryboot_a_b=1 and distinct [all]/[tryboot]
# boot_partition values, both in {A,B}. Returns 0 if valid.
_autoboot_valid() {

	[ -f "$1" ] || return 1

	awk -v a="$BOOT_SLOT_A" -v b="$BOOT_SLOT_B" '
		/^\[all\]/       { sec = "all" }
		/^\[tryboot\]/   { sec = "tryboot" }
		/^tryboot_a_b=1/ { tab = 1 }
		/^boot_partition=/ {
			v = $0; sub(/.*=/, "", v); sub(/[^0-9].*/, "", v)
			if (sec == "all")     allp = v
			if (sec == "tryboot") tryp = v
		}
		END {
			if (tab == 1 && (allp == a || allp == b) && (tryp == a || tryp == b) && allp != tryp) exit 0
			exit 1
		}' "$1" 2>/dev/null
}

# True if the firmware booted the one-shot tryboot slot.
_in_tryboot() {

	[ -e "$BOOT_TRYBOOT" ] || return 1
	th=$(hexdump -v -e '/1 "%02x"' "$BOOT_TRYBOOT" 2>/dev/null || true)
	[ "$th" = "00000001" ]
}

# On a tryboot boot with a pending update move SWUpdate's ustate to
# STATE_TESTING (2) before userspace (and suricatta) start
mark_update_testing() {

	[ "$(fw_printenv -n upgrade_available 2>/dev/null)" = "1" ] || return 0
	_in_tryboot || return 0

	# Already testing: nothing to do (avoid a redundant env write).
	[ "$(fw_printenv -n ustate 2>/dev/null)" = "2" ] && return 0

	klog "ab-slot: tryboot with pending update, marking ustate=2 (testing)"
	fw_setenv ustate 2 || klog "ab-slot: failed to set ustate=2"
}

# Current running boot partition number from the firmware device-tree node.
_running_boot_part() {

	rh=$(hexdump -v -e '/1 "%02x"' "$BOOT_SLOT" 2>/dev/null || true)
	case "$rh" in
		00000002) echo "$BOOT_SLOT_A" ;;
		00000003) echo "$BOOT_SLOT_B" ;;
	esac
}

# check/repair a corrupt autoboot.txt while an update is pending:
# With EEPROM partition walking a corrupt autoboot.txt does not brick: the
# bootloader walks partitions, boots a slot with a valid boot.img, and we land
# here. The boot is therefore not driven by autoboot.txt, so the intended layout
# comes from the bootloader env (off the vfat), not the device tree. On a pending
# update this forces a rollback to the known-good (previous) slot.
#
# Expects the selector partition already mounted at $ROOT_MNT$BOOT_MNT.
check_autoboot() {

	# Only relevant while an update is awaiting verification.
	[ "$(fw_printenv -n upgrade_available 2>/dev/null)" = "1" ] || return 0

	autoboot="$ROOT_MNT$BOOT_MNT/autoboot.txt"
	_autoboot_valid "$autoboot" && return 0

	klog "autoboot: autoboot.txt missing or corrupt, repairing (pending update -> rollback)"

	target=$(fw_printenv -n update_target_slot 2>/dev/null || true)
	case "$target" in
		A) target_part="$BOOT_SLOT_A" ;;
		B) target_part="$BOOT_SLOT_B" ;;
		*) target_part="" ;;
	esac

	running_part=$(_running_boot_part)

	if [ -n "$target_part" ]; then
		# Known-good (previous) slot is the one we did NOT update.
		active_part=$(_other_boot_part "$target_part")
		candidate_part="$target_part"
	else
		# update_target_slot unknown: write a valid file for the running slot,
		# do not force a rollback
		klog "autoboot: update_target_slot unset, rebuilding for running slot $running_part"
		active_part="$running_part"
		candidate_part=$(_other_boot_part "$running_part")
	fi

	[ -n "$active_part" ] && [ -n "$candidate_part" ] || {
		klog "autoboot: cannot determine slots, leaving autoboot.txt as-is"
		return 0
	}

	tmp="$autoboot.new"
	cat > "$tmp" <<EOF
[all]
tryboot_a_b=1
boot_partition=$active_part

[tryboot]
boot_partition=$candidate_part
EOF
	sync
	mv "$tmp" "$autoboot" || {
		klog "autoboot: failed to write $autoboot"
		rm -f "$tmp"
		return 0
	}
	sync

	klog "autoboot: restored [all]=$active_part [tryboot]=$candidate_part"

	# Record the failed update and clear the pending state.
	fw_setenv ustate 3            || klog "autoboot: failed to set ustate"
	fw_setenv upgrade_available   || klog "autoboot: failed to clear upgrade_available"

	# If the walk left us on a slot other than the known-good one, reboot so the
	# now-valid autoboot.txt boots the known-good slot.
	if [ -n "$running_part" ] && [ "$running_part" != "$active_part" ]; then
		klog "autoboot: running slot $running_part != known-good $active_part, rebooting"
		sync
		reboot -f
	fi
}
