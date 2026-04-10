SUMMARY = "PKCS#11 module for Raspberry Pi firmware OTP ECDSA keys"
HOMEPAGE = "https://github.com/embetrix/rpifwcrypto-pkcs11"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736"

SRC_URI = "git://github.com/embetrix/rpifwcrypto-pkcs11.git;protocol=https;branch=master"
SRCREV = "d7becadf2fdf37896fb03eb25ec72b70a67a0483"

S = "${WORKDIR}/git"

inherit cmake

DEPENDS = "raspi-utils"

FILES:${PN} += "${libdir}/pkcs11 ${datadir}/p11-kit"
INSANE_SKIP:${PN} += "dev-so"

RRECOMMENDS:${PN} = "raspi-utils-rpifwcrypto pkcs11-provider libp11"

COMPATIBLE_MACHINE = "raspberrypi4|raspberrypi4-64|raspberrypi5"
