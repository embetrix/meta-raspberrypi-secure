SUMMARY = "A C tool that verifies Android Verified Boot (AVB) signed images \
          using libavb and extracts dm-verity parameters for use with dmsetup"
HOMEPAGE = "https://github.com/embetrix/avb-verify"
LICENSE = "GPL-3.0-or-later & Apache-2.0 & MIT & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736 \
                    file://avb/LICENSE;md5=b8228f2369d92593f53f0a0685ebd3c0"

SRCREV_FORMAT = "avb-verify_avb"
SRCREV_avb-verify = "3d7aa915733f18d96c23d617c8cb1b483657416c"
SRCREV_avb = "4a4e2c8a6592b88cf18b10fe5406f53a2a5d26cf"

SRC_URI = " \
    git://github.com/embetrix/avb-verify.git;name=avb-verify;protocol=https;branch=master \
    git://android.googlesource.com/platform/external/avb;name=avb;protocol=https;nobranch=1;destsuffix=git/avb \
    "

S = "${WORKDIR}/git"

inherit cmake pkgconfig

CFLAGS += "-DAVB_COMPILATION"

RDEPENDS:${PN} = "avb-keys"
