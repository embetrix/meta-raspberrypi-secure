FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://rules.conf"


do_install:append() {
    install -d ${D}${sysconfdir}/usbguard
    install -m 0600 ${WORKDIR}/rules.conf ${D}${sysconfdir}/usbguard/
}
