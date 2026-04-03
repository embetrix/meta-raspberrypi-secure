HOMEPAGE = "https://android.googlesource.com/platform/external/avb/"

LICENSE = "MIT & Apache-2.0 & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b8228f2369d92593f53f0a0685ebd3c0"

SRCREV = "4a4e2c8a6592b88cf18b10fe5406f53a2a5d26cf"
SRC_URI = "git://android.googlesource.com/platform/external/avb;protocol=https;nobranch=1"

S = "${WORKDIR}/git"

PV = "1.4.0"

BBCLASSEXTEND = "native nativesdk"
