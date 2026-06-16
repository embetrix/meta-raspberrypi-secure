# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

SUMMARY = "A/B partition update script"
DESCRIPTION = "Update the inactive boot and root redundant partitions based on the current boot slot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://rpi-ab-update.sh"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${UNPACKDIR}/rpi-ab-update.sh ${D}${sbindir}/rpi-ab-update
}

COMPATIBLE_MACHINE = "raspberrypi4|raspberrypi4-64|raspberrypi5"
