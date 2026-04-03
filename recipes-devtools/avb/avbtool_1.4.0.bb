SUMMARY = "Android Verified Boot 2.0 tool"
DESCRIPTION = "avbtool is the command-line tool for generating vbmeta images, \
signing boot images and managing AVB metadata for Android Verified Boot"
SECTION = "devel"
LICENSE = "MIT"

require avb.inc

inherit python3native

RDEPENDS:${PN} = "python3-core"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/avbtool.py ${D}${bindir}/avbtool
}
