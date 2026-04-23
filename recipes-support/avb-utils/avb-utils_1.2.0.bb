SUMMARY = "A toolkit that brings Android Verified Boot (AVB) to embedded Linux"
HOMEPAGE = "https://github.com/embetrix/avb-utils"
LICENSE = "GPL-3.0-or-later & Apache-2.0 & MIT & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736 \
                    file://avb/LICENSE;md5=b8228f2369d92593f53f0a0685ebd3c0"

SRCREV_FORMAT = "avb-utils_avb"
SRCREV_avb-utils = "8bc77f443c0ba97856141ad6358cae4bc928e635"
SRCREV_avb = "4a4e2c8a6592b88cf18b10fe5406f53a2a5d26cf"

SRC_URI = " \
    git://github.com/embetrix/avb-utils.git;name=avb-utils;protocol=https;branch=master \
    git://android.googlesource.com/platform/external/avb;name=avb;protocol=https;nobranch=1;destsuffix=git/avb \
    "

S = "${WORKDIR}/git"

inherit cmake pkgconfig

CFLAGS += "-DAVB_COMPILATION"

PACKAGES =+ "${PN}-python"

EXTRA_OECMAKE:class-native = "-DINSTALL_AVB_SIGN=ON"

RDEPENDS:${PN}:class-target = "avb-keys"
RDEPENDS:${PN}-python = "python3-core openssl"

FILES:${PN}-python = "${bindir}/avb_sign ${bindir}/avbtool"

BBCLASSEXTEND = "native nativesdk"
