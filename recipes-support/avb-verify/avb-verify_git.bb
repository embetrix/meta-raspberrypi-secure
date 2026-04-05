SUMMARY = "A C tool that verifies Android Verified Boot (AVB) signed images \
          using libavb and extracts dm-verity parameters for use with dmsetup"
HOMEPAGE = "https://github.com/embetrix/avb-verify"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736"

SRC_URI = "git://github.com/embetrix/avb-verify.git;protocol=https;branch=master"
SRCREV = "a466e20089b128cdd4db7bc8f0d19c85260b6b0c"

DEPENDS = "libavb"

S = "${WORKDIR}/git"

inherit cmake pkgconfig

RDEPENDS:${PN} = "avb-keys"
