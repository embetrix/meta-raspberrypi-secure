# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

SUMMARY = "Raspberry Pi secure boot toggle helper"
DESCRIPTION = "Script to check, enable, or disable secure boot via EEPROM recovery"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://rpi-secureboot.sh"

RDEPENDS:${PN} = "raspi-utils"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/rpi-secureboot.sh ${D}${sbindir}/rpi-secureboot
}

COMPATIBLE_MACHINE = "raspberrypi4|raspberrypi4-64|raspberrypi5"
