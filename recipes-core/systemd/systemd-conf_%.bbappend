FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "\
	file://90-security.conf \
	"

do_install() {
	install -d ${D}${sysconfdir}/sysctl.d
	install -m 644 ${WORKDIR}/90-security.conf ${D}${sysconfdir}/sysctl.d/
}

FILES:${PN} += "${sysconfdir}/sysctl.d"
