FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://ssh_ca.pub"

PACKAGECONFIG:remove = "systemd-sshd-socket-mode"
PACKAGECONFIG:append = " systemd-sshd-service-mode"


do_install:append () {

	for cfg in ${D}${sysconfdir}/ssh/sshd_config ${D}${sysconfdir}/ssh/sshd_config_readonly; do
		[ -e "$cfg" ] || continue
		sed -i -e 's:#AllowTcpForwarding yes:AllowTcpForwarding no:' $cfg
		sed -i -e 's:ClientAliveCountMax 4:ClientAliveCountMax 2:' $cfg
		sed -i -e 's:#LogLevel INFO:LogLevel VERBOSE:' $cfg
		sed -i -e 's:#MaxSessions.*:MaxSessions 2:' $cfg
		sed -i -e 's:#TCPKeepAlive yes:TCPKeepAlive no:' $cfg
		sed -i -e 's:#AllowAgentForwarding yes:AllowAgentForwarding no:' $cfg
		sed -i -e 's:#PermitRootLogin.*:PermitRootLogin prohibit-password:' $cfg
		if grep -q '^[#[:space:]]*TrustedUserCAKeys[[:space:]]' $cfg; then
			sed -i -e 's:^[#[:space:]]*TrustedUserCAKeys[[:space:]].*:TrustedUserCAKeys /etc/ssh/ssh_ca.pub:' $cfg
		else
			echo 'TrustedUserCAKeys /etc/ssh/ssh_ca.pub' >> $cfg
		fi
	done

	install -m 0644 ${WORKDIR}/ssh_ca.pub ${D}${sysconfdir}/ssh/ssh_ca.pub
}

FILES:${PN}-sshd += "${sysconfdir}/ssh/ssh_ca.pub"
