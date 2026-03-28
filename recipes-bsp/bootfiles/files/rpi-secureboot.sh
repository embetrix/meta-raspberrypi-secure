#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Helper script to check, enable, or disable Raspberry Pi secure boot
# via the EEPROM recovery mechanism on the boot selector partition
set -e

MNT="/mnt"

usage() {

    echo "Usage: $(basename "$0") {status|enable|disable}"
    echo ""
    echo "  status   Show current EEPROM secure boot configuration"
    echo "  enable   Enable secure boot (flash signed EEPROM with SIGNED_BOOT=1)"
    echo "  disable  Disable secure boot (flash recovery EEPROM without SIGNED_BOOT)"
    exit 1
}

find_boot_part() {

    BOOT_PART=$(findfs PARTLABEL=boot 2>/dev/null || true)
    if [ -z "$BOOT_PART" ]; then
        echo "Error: boot partition not found (PARTLABEL=boot)" >&2
        exit 1
    fi
}

do_status() {

    echo "=== EEPROM Bootloader Configuration ==="
    rpi-eeprom-config

    echo ""
    echo "=== Secure Boot Status ==="
    SIGNED_BOOT=$(rpi-eeprom-config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" = "1" ]; then
        echo "Secure boot: ENABLED"
    else
        echo "Secure boot: DISABLED"
    fi

    echo ""
    echo "=== OTP Secure Boot Fuses ==="
    if command -v vcgencmd >/dev/null 2>&1; then
        REVKEY=$(vcgencmd otp_dump | grep "^90:" | cut -d: -f2 || true)
        if [ -n "$REVKEY" ] && [ "$REVKEY" != "00000000" ]; then
            echo "OTP revkey fuses: PROGRAMMED (secure boot is permanent)"
        else
            echo "OTP revkey fuses: NOT programmed (secure boot can be toggled)"
        fi
    else
        echo "vcgencmd not available, cannot check OTP fuses"
    fi
}

mount_boot() {

    find_boot_part
    if mountpoint -q "$MNT"; then
        echo "Error: $MNT is already a mountpoint" >&2
        exit 1
    fi
    mount "$BOOT_PART" "$MNT"
}

umount_boot() {

    umount "$MNT"
}

check_recovery_files() {

    for f in "$@"; do
        if [ ! -f "$MNT/$f" ]; then
            echo "Error: required file $f not found on $BOOT_PART" >&2
            umount_boot
            exit 1
        fi
    done
}

do_enable() {

    echo "=== Checking current status ==="
    SIGNED_BOOT=$(rpi-eeprom-config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" = "1" ]; then
        echo "Secure boot is already enabled."
        exit 0
    fi

    echo "Secure boot is currently DISABLED, preparing to enable..."
    echo ""

    mount_boot
    check_recovery_files "_recovery.bin_" "_pieeprom.upd_" "_pieeprom.upd.sig_"

    cp "$MNT/_pieeprom.upd_" "$MNT/pieeprom.upd"
    cp "$MNT/_pieeprom.upd.sig_" "$MNT/pieeprom.sig"
    cp "$MNT/_recovery.bin_" "$MNT/recovery.bin"
    sync
    umount_boot

    echo "Recovery files staged. Rebooting to flash EEPROM..."
    reboot
}

do_disable() {

    echo "=== Checking current status ==="
    SIGNED_BOOT=$(rpi-eeprom-config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" != "1" ]; then
        echo "Secure boot is already disabled."
        exit 0
    fi

    # Check OTP fuses
    if command -v vcgencmd >/dev/null 2>&1; then
        REVKEY=$(vcgencmd otp_dump | grep "^90:" | cut -d: -f2 || true)
        if [ -n "$REVKEY" ] && [ "$REVKEY" != "00000000" ]; then
            echo "Error: OTP fuses are programmed. Secure boot cannot be disabled." >&2
            exit 1
        fi
    fi

    echo "Secure boot is currently ENABLED, preparing to disable..."
    echo ""

    mount_boot
    check_recovery_files "_recovery.bin_" "_pieeprom.bin_" "_pieeprom.sig_"

    cp "$MNT/_pieeprom.bin_" "$MNT/pieeprom.upd"
    cp "$MNT/_pieeprom.sig_" "$MNT/pieeprom.sig"
    cp "$MNT/_recovery.bin_" "$MNT/recovery.bin"
    sync
    umount_boot

    echo "Recovery files staged. Rebooting to flash EEPROM..."
    reboot
}

case "${1:-}" in
    status)  do_status ;;
    enable)  do_enable ;;
    disable) do_disable ;;
    *)       usage ;;
esac
