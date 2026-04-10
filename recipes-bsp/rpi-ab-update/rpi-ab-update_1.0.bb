# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

SUMMARY = "A/B partition update script"
DESCRIPTION = "Update the inactive boot and root redundant partitions based on the current boot slot"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = "file://rpi-ab-update.sh \
           file://rpi-ab-update-confirm.service \
           file://rpi-ab-update-confirm.timer \
           "

inherit systemd

SYSTEMD_SERVICE:${PN} = "rpi-ab-update-confirm.timer rpi-ab-update-confirm.service"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/rpi-ab-update.sh ${D}${sbindir}/rpi-ab-update

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/rpi-ab-update-confirm.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/rpi-ab-update-confirm.timer ${D}${systemd_system_unitdir}/
}

COMPATIBLE_MACHINE = "raspberrypi4|raspberrypi4-64|raspberrypi5"
