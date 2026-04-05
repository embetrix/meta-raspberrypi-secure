DESCRIPTION = "packagegroup for development tools and utilities"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
                    file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

PACKAGE_ARCH = "${TUNE_PKGARCH}"

inherit packagegroup

PACKAGES = "${PN}"

SUMMARY:packagegroup-dev = "Development support"

RDEPENDS:packagegroup-dev = " \
    packagegroup-core-full-cmdline \
    tcpdump \
    gdbserver \
    strace \
    curl \
    opensc \
    curl \
    htop \
    rpi-eeprom \
    rpi-secureboot \
    rpi-ab-update \
    avb-verify \
    "
