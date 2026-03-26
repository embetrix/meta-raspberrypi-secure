FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://timesyncd.conf \
            file://journal-upload.conf \
            "

SRC_URI += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.conf', '', d)}"

do_install:append() {
	if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
		install -d ${D}${sysconfdir}/sysctl.d
		install -m 644 ${WORKDIR}/security-harden.conf ${D}${sysconfdir}/sysctl.d/90-security-harden.conf
	fi
}

FILES:${PN} += "${sysconfdir}/sysctl.d"
