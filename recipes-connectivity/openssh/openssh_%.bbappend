FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

#
#  Override in local.conf for production:
#  OPENSSH_CA_PUBKEY = "/path/to/prod_ssh_ca.pub"
#
OPENSSH_CA_PUBKEY ??= "${OPENSSH_CA_PUBKEY_DEFAULT}"
OPENSSH_CA_PUBKEY_DEFAULT := "${THISDIR}/${PN}/ssh_ca_dev.pub"

SRC_URI += "file://sshd-time-sync.conf"

PACKAGECONFIG:remove = "systemd-sshd-socket-mode"
PACKAGECONFIG:append = " systemd-sshd-service-mode"

do_install:append () {

	for cfg in ${D}${sysconfdir}/ssh/sshd_config ${D}${sysconfdir}/ssh/sshd_config_readonly; do
		[ -e "$cfg" ] || continue
		if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
			sed -i -e 's:#AllowTcpForwarding yes:AllowTcpForwarding no:' $cfg
			sed -i -e 's:ClientAliveCountMax 4:ClientAliveCountMax 2:' $cfg
			sed -i -e 's:#LogLevel INFO:LogLevel VERBOSE:' $cfg
			sed -i -e 's:#MaxSessions.*:MaxSessions 2:' $cfg
			sed -i -e 's:#TCPKeepAlive yes:TCPKeepAlive no:' $cfg
			sed -i -e 's:#AllowAgentForwarding yes:AllowAgentForwarding no:' $cfg
			sed -i -e 's:#PasswordAuthentication yes:PasswordAuthentication no:' $cfg
			sed -i -e 's:#PermitRootLogin.*:PermitRootLogin prohibit-password:' $cfg
			echo 'TrustedUserCAKeys /etc/ssh/certs/ssh_ca.pub' >> $cfg
		fi
	done

    # Keep generated host keys persistent on /etc/ssh/keys
	# bind-mounted from /var/data/etc/ssh/keys
    install -d ${D}${sysconfdir}/ssh/keys
	sed -i 's|#HostKey /etc/ssh|HostKey /etc/ssh/keys|g' ${D}${sysconfdir}/ssh/sshd_config
	sed -i 's|HostKey /var/run/ssh|HostKey /etc/ssh/keys|g' ${D}${sysconfdir}/ssh/sshd_config_readonly

    install -d ${D}${sysconfdir}/ssh/certs
	install -m 0644 ${OPENSSH_CA_PUBKEY} ${D}${sysconfdir}/ssh/certs/ssh_ca.pub
	if [ "${RPI_SECURITY_PROFILE}" = "prod" ] && echo "${OPENSSH_CA_PUBKEY}" | grep -q "ssh_ca_dev\.pub$"; then
		bbfatal "!!!! Production build is using the dev SSH CA public key : set OPENSSH_CA_PUBKEY to a production key !!!!!"
	fi

	# Drop-in: start sshd after NTP sync (certificate validity needs correct time)
	install -d ${D}${systemd_system_unitdir}/sshd.service.d
	install -m 0644 ${WORKDIR}/sshd-time-sync.conf ${D}${systemd_system_unitdir}/sshd.service.d/time-sync.conf
}

FILES:${PN}-sshd += "${sysconfdir}/ssh/certs \
	                 ${sysconfdir}/ssh/keys \
					 ${systemd_system_unitdir}/sshd.service.d"
