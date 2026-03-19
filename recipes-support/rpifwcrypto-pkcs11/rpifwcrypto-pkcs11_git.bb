SUMMARY = "PKCS#11 module for Raspberry Pi firmware OTP ECDSA keys"
HOMEPAGE = "https://github.com/embetrix/rpifwcrypto-pkcs11"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736"

SRC_URI = "git://github.com/embetrix/rpifwcrypto-pkcs11.git;protocol=https;branch=master"
SRCREV = "8414db2b536fb2d4c13ae419c5da914794719f55"

S = "${WORKDIR}/git"

inherit cmake

DEPENDS = "raspi-utils"

FILES:${PN} += "${libdir}/pkcs11 ${datadir}/p11-kit"
INSANE_SKIP:${PN} += "dev-so"

RRECOMMENDS:${PN} = "raspi-utils pkcs11-provider"
