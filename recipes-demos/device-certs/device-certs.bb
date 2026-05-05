SUMMARY = "Device certificates"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
           file://nginx-pkcs11.conf \
           file://nginx-extra.conf \
           file://device-certs.sh \
           file://device-certs.service \
           "

inherit systemd

DEPENDS = "openssl-native"
RDEPENDS:${PN} += "openssl-bin hostname-setup nginx rpifwcrypto-pkcs11"

do_install () {
    install -d ${D}${sysconfdir}/certs
   
    install -d ${D}${sysconfdir}/nginx/conf.d
    install -m 0644 ${WORKDIR}/nginx-pkcs11.conf ${D}${sysconfdir}/nginx/conf.d/nginx-pkcs11.conf

    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/device-certs.sh       ${D}${bindir}/device-certs
}

SYSTEMD_SERVICE:${PN} = "device-certs.service"
SYSTEMD_PACKAGES = "${PN}"

do_install:append() {
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${WORKDIR}/device-certs.service ${D}${systemd_unitdir}/system/

    install -d ${D}${systemd_unitdir}/system/nginx.service.d
    install -m 0644 ${WORKDIR}/nginx-extra.conf ${D}${systemd_unitdir}/system/nginx.service.d/

}

FILES:${PN} = "${bindir} \
               ${sysconfdir}/certs \
               ${sysconfdir}/nginx/conf.d \
               ${sysconfdir}/systemd \
               ${systemd_unitdir}/system/nginx.service.d \
             "
