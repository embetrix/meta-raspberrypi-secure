FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://main.nft \
    file://rules.d/00-definitions.nft \
    file://rules.d/10-sets.nft \
    file://rules.d/20-input.nft \
    file://rules.d/30-forward.nft \
    file://rules.d/40-output.nft \
    "

inherit systemd

PACKAGECONFIG[systemd] = "--with-unitdir=${systemd_system_unitdir}, --without-unitdir"
PACKAGECONFIG:append = " ${@bb.utils.filter('DISTRO_FEATURES', 'systemd', d)}"
SYSTEMD_SERVICE:${PN} = "nftables.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install:append() {
    install -d ${D}${sysconfdir}/nftables/rules
    install -m 0644 ${UNPACKDIR}/main.nft ${D}${sysconfdir}/nftables/rules/main.nft

    install -d ${D}${sysconfdir}/nftables/rules.d
    install -m 0644 ${UNPACKDIR}/rules.d/*.nft ${D}${sysconfdir}/nftables/rules.d/
}

FILES:${PN} += "${sysconfdir}/nftables"
