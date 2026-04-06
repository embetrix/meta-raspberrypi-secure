#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Helper script to check, enable, or disable Raspberry Pi secure boot
# via the EEPROM recovery mechanism on the boot selector partition
set -e

BOOT_MNT="/boot"

usage() {

    echo "Usage: $(basename "$0") {status|enable|disable}"
    echo ""
    echo "  status   Show current EEPROM secure boot configuration"
    echo "  enable   Enable secure boot (flash signed EEPROM with SIGNED_BOOT=1)"
    echo "  disable  Disable secure boot (flash recovery EEPROM without SIGNED_BOOT)"
    exit 1
}

do_status() {

    echo "=== EEPROM Bootloader Configuration ==="
    vcgencmd bootloader_config

    echo ""
    echo "=== Secure Boot Status ==="
    SIGNED_BOOT=$(vcgencmd bootloader_config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" = "1" ]; then
        echo "Secure boot: ENABLED"
    else
        echo "Secure boot: DISABLED"
    fi

    echo ""
    echo "=== OTP Secure Boot Fuses ==="
    REVKEY=$(vcgencmd otp_dump | grep "^90:" | cut -d: -f2 || true)
    if [ -n "$REVKEY" ] && [ "$REVKEY" != "00000000" ]; then
        echo "OTP revkey fuses: PROGRAMMED (secure boot is permanent)"
    else
        echo "OTP revkey fuses: NOT programmed (secure boot can be toggled)"
    fi
}

check_recovery_files() {

    for f in "$@"; do
        if [ ! -f "$BOOT_MNT/$f" ]; then
            echo "Error: required file $f not found on boot partition" >&2
            exit 1
        fi
    done
}

do_enable() {

    echo "=== Checking current status ==="
    SIGNED_BOOT=$(vcgencmd bootloader_config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" = "1" ]; then
        echo "Secure boot is already enabled."
        exit 0
    fi

    echo "Secure boot is currently DISABLED, preparing to enable..."
    echo ""

    check_recovery_files "_recovery.bin_" "_pieeprom.upd_" "_pieeprom.upd.sig_"

    cp "$BOOT_MNT/_pieeprom.upd_" "$BOOT_MNT/pieeprom.upd"
    cp "$BOOT_MNT/_pieeprom.upd.sig_" "$BOOT_MNT/pieeprom.sig"
    cp "$BOOT_MNT/_recovery.bin_" "$BOOT_MNT/recovery.bin"
    sync

    echo "Recovery files staged. Rebooting to flash EEPROM..."
    reboot
}

do_disable() {

    echo "=== Checking current status ==="
    SIGNED_BOOT=$(vcgencmd bootloader_config 2>/dev/null | grep -i "^SIGNED_BOOT=" | cut -d= -f2 || true)
    if [ "$SIGNED_BOOT" != "1" ]; then
        echo "Secure boot is already disabled."
        exit 0
    fi

    # Check OTP fuses
    REVKEY=$(vcgencmd otp_dump | grep "^90:" | cut -d: -f2 || true)
    if [ -n "$REVKEY" ] && [ "$REVKEY" != "00000000" ]; then
        echo "Error: OTP fuses are programmed. Secure boot cannot be disabled." >&2
        exit 1
    fi

    echo "Secure boot is currently ENABLED, preparing to disable..."
    echo ""

    check_recovery_files "_recovery.bin_" "_pieeprom.bin_" "_pieeprom.sig_"

    cp "$BOOT_MNT/_pieeprom.bin_" "$BOOT_MNT/pieeprom.upd"
    cp "$BOOT_MNT/_pieeprom.sig_" "$BOOT_MNT/pieeprom.sig"
    cp "$BOOT_MNT/_recovery.bin_" "$BOOT_MNT/recovery.bin"
    sync

    echo "Recovery files staged. Rebooting to flash EEPROM..."
    reboot
}

case "${1:-}" in
    status)  do_status ;;
    enable)  do_enable ;;
    disable) do_disable ;;
    *)       usage ;;
esac
