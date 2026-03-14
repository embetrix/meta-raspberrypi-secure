FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://90-security.conf \
            file://timesyncd.conf"

do_install:append() {
	install -d ${D}${sysconfdir}/sysctl.d
	install -m 644 ${WORKDIR}/90-security.conf ${D}${sysconfdir}/sysctl.d/
}

FILES:${PN} += "${sysconfdir}/sysctl.d"
