FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

OPENSSH_CA_PUBKEY ??= ""

SRC_URI += "file://sshd-time-sync.conf"

PACKAGECONFIG:remove = "systemd-sshd-socket-mode"
PACKAGECONFIG:append = " systemd-sshd-service-mode"

do_install:append () {

	if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
		for cfg in ${D}${sysconfdir}/ssh/sshd_config ${D}${sysconfdir}/ssh/sshd_config_readonly; do
			[ -e "$cfg" ] || continue
				sed -i -e 's:#AllowTcpForwarding yes:AllowTcpForwarding no:' $cfg
				sed -i -e 's:ClientAliveCountMax 4:ClientAliveCountMax 2:' $cfg
				sed -i -e 's:#LogLevel INFO:LogLevel VERBOSE:' $cfg
				sed -i -e 's:#MaxSessions.*:MaxSessions 2:' $cfg
				sed -i -e 's:#TCPKeepAlive yes:TCPKeepAlive no:' $cfg
				sed -i -e 's:#AllowAgentForwarding yes:AllowAgentForwarding no:' $cfg
				sed -i -e 's:#PasswordAuthentication yes:PasswordAuthentication no:' $cfg
				sed -i -e 's:#PermitRootLogin.*:PermitRootLogin prohibit-password:' $cfg
				echo 'TrustedUserCAKeys /etc/ssh/certs/ssh_ca.pub' >> $cfg
		done
	fi

    # Keep generated host keys persistent on /etc/ssh/keys
	# bind-mounted from /var/data/etc/ssh/keys
    install -d ${D}${sysconfdir}/ssh/keys
	sed -i 's|#HostKey /etc/ssh|HostKey /etc/ssh/keys|g' ${D}${sysconfdir}/ssh/sshd_config
	sed -i 's|HostKey /var/run/ssh|HostKey /etc/ssh/keys|g' ${D}${sysconfdir}/ssh/sshd_config_readonly

    install -d ${D}${sysconfdir}/ssh/certs
	if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
		if [ -z "${OPENSSH_CA_PUBKEY}" ] || [ ! -f "${OPENSSH_CA_PUBKEY}" ]; then
			bbfatal "Production build requires OPENSSH_CA_PUBKEY to be set to a valid SSH CA public key"
		fi
		install -m 0644 ${OPENSSH_CA_PUBKEY} ${D}${sysconfdir}/ssh/certs/ssh_ca.pub
	fi

	# Drop-in: start sshd after NTP sync (certificate validity needs correct time)
	install -d ${D}${systemd_system_unitdir}/sshd.service.d
	install -m 0644 ${UNPACKDIR}/sshd-time-sync.conf ${D}${systemd_system_unitdir}/sshd.service.d/time-sync.conf
}

FILES:${PN}-sshd += "${sysconfdir}/ssh/certs \
	                 ${sysconfdir}/ssh/keys \
					 ${systemd_system_unitdir}/sshd.service.d"
