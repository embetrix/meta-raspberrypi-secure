FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://security.rules"

do_install:append() {
    install -d -m 750 ${D}${sysconfdir}/audit/rules.d
    install -m 0640 ${WORKDIR}/security.rules ${D}${sysconfdir}/audit/rules.d/
}
