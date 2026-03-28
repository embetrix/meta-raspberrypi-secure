# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

SUMMARY = "Raspberry Pi secure boot toggle helper"
DESCRIPTION = "Script to check, enable, or disable secure boot via EEPROM recovery"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = "file://rpi-secureboot.sh"

RDEPENDS:${PN} = "rpi-eeprom util-linux-findfs"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/rpi-secureboot.sh ${D}${sbindir}/rpi-secureboot
}
