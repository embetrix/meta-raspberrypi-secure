SUMMARY = "PKCS#11 module for Raspberry Pi firmware OTP ECDSA keys"
HOMEPAGE = "https://github.com/embetrix/rpifwcrypto-pkcs11"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9d121eb775096c0ba619421933ef0736"

SRC_URI = "git://github.com/embetrix/rpifwcrypto-pkcs11.git;protocol=https;branch=master \
           file://99-vcio.rules \
          "
SRCREV = "942f6d2acec9cda964da01339dca923217820448"

inherit cmake useradd

DEPENDS = "raspi-utils"

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-r rpifwcrypto"

do_install:append() {
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/99-vcio.rules ${D}${sysconfdir}/udev/rules.d/
}

FILES:${PN} += "${libdir}/pkcs11 ${datadir}/p11-kit ${sysconfdir}/udev/rules.d"
INSANE_SKIP:${PN} += "dev-so"

RRECOMMENDS:${PN} = "raspi-utils-rpifwcrypto pkcs11-provider libp11"

COMPATIBLE_MACHINE = "raspberrypi4|raspberrypi4-64|raspberrypi5"
