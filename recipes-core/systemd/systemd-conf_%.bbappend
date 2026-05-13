FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://timesyncd.conf \
            file://journal-upload.conf \
			file://80-wlan.network \
			file://rfkill-override.conf \
			file://timesyncd-override.conf \
			${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.conf', '', d)} \
            "

do_install:append() {
	if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
		install -d ${D}${sysconfdir}/sysctl.d
		install -m 644 ${UNPACKDIR}/security-harden.conf ${D}${sysconfdir}/sysctl.d/90-security-harden.conf
	fi

	install -d ${D}/${systemd_unitdir}/network
	install -m 644 ${UNPACKDIR}/80-wlan.network ${D}/${systemd_unitdir}/network/

	# Drop-in: defer systemd-rfkill until /var/lib volatile-bind is in place
	install -d ${D}${systemd_system_unitdir}/systemd-rfkill.service.d
	install -m 644 ${UNPACKDIR}/rfkill-override.conf \
		${D}${systemd_system_unitdir}/systemd-rfkill.service.d/override.conf

	# Drop-in: defer systemd-timesyncd until /var/lib tmpfs is mounted
	install -d ${D}${systemd_system_unitdir}/systemd-timesyncd.service.d
	install -m 644 ${UNPACKDIR}/timesyncd-override.conf \
		${D}${systemd_system_unitdir}/systemd-timesyncd.service.d/override.conf
}

FILES:${PN} += "${sysconfdir}/sysctl.d \
				${systemd_unitdir}/network \
				${systemd_system_unitdir}/systemd-rfkill.service.d \
				${systemd_system_unitdir}/systemd-timesyncd.service.d"
