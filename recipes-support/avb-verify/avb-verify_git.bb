SUMMARY = "A C tool that verifies Android Verified Boot (AVB) signed images \
          using libavb and extracts dm-verity parameters for use with dmsetup"
HOMEPAGE = "https://github.com/embetrix/avb-verify"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736"

SRC_URI = "git://github.com/embetrix/avb-verify.git;protocol=https;branch=master"
SRCREV = "e5cbc45586754eed120fb6dd0fd007d31775a98e"

DEPENDS = "libavb"

S = "${WORKDIR}/git"

inherit cmake pkgconfig

RDEPENDS:${PN} = "avb-keys"
