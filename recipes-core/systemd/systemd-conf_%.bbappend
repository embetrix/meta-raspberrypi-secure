FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://timesyncd.conf \
            file://journal-upload.conf \
			file://80-wlan.network \
			file://rfkill-override.conf \
            "

SRC_URI += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.conf', '', d)}"

do_install:append() {
	if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
		install -d ${D}${sysconfdir}/sysctl.d
		install -m 644 ${WORKDIR}/security-harden.conf ${D}${sysconfdir}/sysctl.d/90-security-harden.conf
	fi

	install -d ${D}/${systemd_unitdir}/network
	install -m 644 ${WORKDIR}/80-wlan.network ${D}/${systemd_unitdir}/network/

	# Drop-in: defer systemd-rfkill until /var/lib volatile-bind is in place
	install -d ${D}${systemd_system_unitdir}/systemd-rfkill.service.d
	install -m 644 ${WORKDIR}/rfkill-override.conf \
		${D}${systemd_system_unitdir}/systemd-rfkill.service.d/override.conf
}

FILES:${PN} += "${sysconfdir}/sysctl.d \
				${systemd_unitdir}/network \
				${systemd_system_unitdir}/systemd-rfkill.service.d"
