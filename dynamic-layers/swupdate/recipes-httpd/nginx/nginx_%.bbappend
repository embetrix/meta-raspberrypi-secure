FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://swupdate.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/nginx/default-server.d
    install -m 0644 ${UNPACKDIR}/swupdate.conf ${D}${sysconfdir}/nginx/default-server.d/swupdate.conf
}

FILES:${PN} += "${sysconfdir}/nginx/default-server.d/swupdate.conf"
CONFFILES:${PN} += "${sysconfdir}/nginx/default-server.d/swupdate.conf"
