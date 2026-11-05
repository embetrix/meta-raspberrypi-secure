FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://client-startup.conf"

SYSTEMD_SERVICE:${PN} = "openvpn-client@vpn.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "volatile-binds"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}/openvpn-client@vpn.service.d
    install -m 0644 ${UNPACKDIR}/client-startup.conf \
        ${D}${systemd_system_unitdir}/openvpn-client@vpn.service.d/startup.conf
}

FILES:${PN} += "${systemd_system_unitdir}/openvpn-client@vpn.service.d"
