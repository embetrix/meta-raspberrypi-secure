SUMMARY = "RPi Device certificates"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
           file://nginx-pkcs11.conf \
           file://nginx-override.conf \
           file://rpi-device-certs.sh \
           file://rpi-device-certs.service \
           "

S = "${UNPACKDIR}"

inherit systemd

DEPENDS = "openssl-native"
RDEPENDS:${PN} += "openssl-bin hostname-setup nginx rpifwcrypto-pkcs11"

do_install () {
    install -d ${D}${sysconfdir}/certs
   
    install -d ${D}${sysconfdir}/nginx/conf.d
    install -m 0644 ${UNPACKDIR}/nginx-override.conf ${D}${sysconfdir}/nginx/conf.d/nginx-override.conf

    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/rpi-device-certs.sh       ${D}${bindir}/rpi-device-certs
}

SYSTEMD_SERVICE:${PN} = "rpi-device-certs.service"
SYSTEMD_PACKAGES = "${PN}"

do_install:append() {
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${UNPACKDIR}/rpi-device-certs.service ${D}${systemd_unitdir}/system/

    install -d ${D}${systemd_unitdir}/system/nginx.service.d
    install -m 0644 ${UNPACKDIR}/nginx-override.conf ${D}${systemd_unitdir}/system/nginx.service.d/

}

FILES:${PN} = "${bindir} \
               ${sysconfdir}/certs \
               ${sysconfdir}/nginx/conf.d \
               ${sysconfdir}/systemd \
               ${systemd_unitdir}/system/nginx.service.d \
             "
