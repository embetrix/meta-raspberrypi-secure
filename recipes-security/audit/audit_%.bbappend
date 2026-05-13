FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://security.rules \
            file://audit-rules-override.conf"

RDEPENDS:auditd += "audispd-plugins"

do_install:append() {
    install -d -m 750 ${D}${sysconfdir}/audit/rules.d
    install -m 0640 ${UNPACKDIR}/security.rules ${D}${sysconfdir}/audit/rules.d/

    # Merge upstream base rules with our extra rules into the single file auditctl loads
    cat ${D}${sysconfdir}/audit/audit.rules ${UNPACKDIR}/security.rules \
        > ${D}${sysconfdir}/audit/audit.rules.tmp
    install -m 0640 ${D}${sysconfdir}/audit/audit.rules.tmp ${D}${sysconfdir}/audit/audit.rules
    rm ${D}${sysconfdir}/audit/audit.rules.tmp

    # Systemd Drop-in: replace augenrules with auditctl
    install -d ${D}${systemd_unitdir}/system/audit-rules.service.d
    install -m 0644 ${UNPACKDIR}/audit-rules-override.conf ${D}${systemd_unitdir}/system/audit-rules.service.d/override.conf

    # Enable syslog plugin so audit events are forwarded to journald
    sed -i 's/^active = no/active = yes/' ${D}${sysconfdir}/audit/plugins.d/syslog.conf
}

FILES:auditd += "${systemd_unitdir}/system/audit-rules.service.d"
