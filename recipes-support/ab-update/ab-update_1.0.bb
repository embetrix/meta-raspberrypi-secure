# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

SUMMARY = "A/B partition update script"
DESCRIPTION = "Update the inactive boot and root redundant partitions based on the current boot slot"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = "file://ab-update.sh"

#RDEPENDS:${PN} = ""

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/ab-update.sh ${D}${sbindir}/ab-update
}
