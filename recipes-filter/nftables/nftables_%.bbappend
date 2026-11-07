FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://firewall.nft \
    "

SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install:append() {
    install -d ${D}${sysconfdir}/nftables/rules
    install -m 0644 ${UNPACKDIR}/firewall.nft ${D}${sysconfdir}/nftables/rules/main.nft
}

FILES:${PN} += "${sysconfdir}/nftables"
