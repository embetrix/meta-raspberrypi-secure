SUMMARY = "RPi Device certificates"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://rpi-device-certs.sh \
           file://rpi-device-certs.service \
           "

S = "${UNPACKDIR}"

inherit systemd

DEPENDS = "openssl-native"
RDEPENDS:${PN} += "openssl-bin hostname-setup rpifwcrypto-pkcs11"

do_install () {
    install -d ${D}${sysconfdir}/certs
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/rpi-device-certs.sh       ${D}${bindir}/rpi-device-certs
}

SYSTEMD_SERVICE:${PN} = "rpi-device-certs.service"
SYSTEMD_PACKAGES = "${PN}"

do_install:append() {
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${UNPACKDIR}/rpi-device-certs.service ${D}${systemd_unitdir}/system/
}

FILES:${PN} = "${bindir} \
               ${sysconfdir}/certs \
               ${sysconfdir}/systemd \
               "
