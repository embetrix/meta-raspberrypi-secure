FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://ssh_ca.pub"


do_install:append () {

	sed -i -e 's:#AllowTcpForwarding yes:AllowTcpForwarding no:' ${D}${sysconfdir}/ssh/sshd_config
	sed -i -e 's:ClientAliveCountMax 4:ClientAliveCountMax 2:' ${D}${sysconfdir}/ssh/sshd_config
	sed -i -e 's:#LogLevel INFO:LogLevel VERBOSE:' ${D}${sysconfdir}/ssh/sshd_config
	sed -i -e 's:#MaxSessions.*:MaxSessions 2:' ${D}${sysconfdir}/ssh/sshd_config
	sed -i -e 's:#TCPKeepAlive yes:TCPKeepAlive no:' ${D}${sysconfdir}/ssh/sshd_config
	sed -i -e 's:#AllowAgentForwarding yes:AllowAgentForwarding no:' ${D}${sysconfdir}/ssh/sshd_config
    sed -i -e 's:#PermitRootLogin.*:PermitRootLogin prohibit-password:' ${D}${sysconfdir}/ssh/sshd_config
	if grep -q '^[#[:space:]]*TrustedUserCAKeys[[:space:]]' ${D}${sysconfdir}/ssh/sshd_config; then
		sed -i -e 's:^[#[:space:]]*TrustedUserCAKeys[[:space:]].*:TrustedUserCAKeys /etc/ssh/ssh_ca.pub:' ${D}${sysconfdir}/ssh/sshd_config
	else
		echo 'TrustedUserCAKeys /etc/ssh/ssh_ca.pub' >> ${D}${sysconfdir}/ssh/sshd_config
	fi
    
	install -m 0644 ${WORKDIR}/ssh_ca.pub ${D}${sysconfdir}/ssh/ssh_ca.pub
}

FILES:${PN}-sshd += "${sysconfdir}/ssh/ssh_ca.pub"
