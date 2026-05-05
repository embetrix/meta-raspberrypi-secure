FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://firewall.nft \
    file://nftables.service \
"

PACKAGECONFIG:remove = "python"

inherit systemd

SYSTEMD_SERVICE:${PN} = "nftables.service"

do_install:append() {
    install -d ${D}${sysconfdir}/nftables
    install -m 0644 ${WORKDIR}/firewall.nft ${D}${sysconfdir}/nftables/

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/nftables.service ${D}${systemd_unitdir}/system/
}

FILES:${PN} += "${sysconfdir}/nftables"
