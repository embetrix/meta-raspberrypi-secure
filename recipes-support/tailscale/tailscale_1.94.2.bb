SUMMARY = "Tailscale client and daemon"
DESCRIPTION = "The easiest, most secure way to use WireGuard and 2FA"
HOMEPAGE = "https://github.com/tailscale/tailscale"
SECTION = "networking"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=a672713a9eb730050e491c92edf7984d"

MAJOR_MINOR = "${@oe.utils.trim_version('${PV}', 2)}"
SRC_URI = "git://github.com/tailscale/tailscale.git;protocol=https;branch=release-branch/${MAJOR_MINOR} \
		   file://tailscaled.service \
		   file://tailscale-webui.service \
		   file://tailscale-certs.sh \
		   file://tailscale-certs.service \
		   file://tailscale-certs.timer \
		  "
SRCREV = "2de4d317a8c2595904f1563ebd98fdcf843da275"

S = "${WORKDIR}/git"

GO_IMPORT = "tailscale.com"
GO_INSTALL = "${GO_IMPORT}/cmd/tailscaled"
GO_LINKSHARED = ""
GOBUILDFLAGS:prepend = "-tags=${@','.join(d.getVar('PACKAGECONFIG_CONFARGS').split())} "
GO_EXTRA_LDFLAGS = "-X tailscale.com/version.longStamp=${PV}-${@d.getVar('SRCREV')[:8]} -X tailscale.com/version.shortStamp=${PV}"

inherit go-mod systemd useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "--system --gid 900 tailscale"
USERADD_PARAM:${PN} = "--system --no-create-home --uid 900 -g tailscale -s /bin/false tailscale"

# Prevent Go from downloading a different toolchain version
export GOTOOLCHAIN = "local"

export GOPROXY = "https://proxy.golang.org,direct"
# Workaround for network access issue during compile step.
# This needs to be fixed in the recipes buildsystem so that
# it can be accomplished during do_fetch task.
do_compile[network] = "1"

PACKAGECONFIG ??= "aws bird capture cli kube ssh tap wakeonlan"
PACKAGECONFIG[aws] = "ts_aws,ts_omit_aws"
PACKAGECONFIG[bird] = "ts_bird,ts_omit_bird"
PACKAGECONFIG[capture] = "ts_capture,ts_omit_capture"
PACKAGECONFIG[cli] = "ts_include_cli,ts_omit_include_cli"
PACKAGECONFIG[completion] = "ts_completion,ts_omit_completion"
PACKAGECONFIG[kube] = "ts_kube,ts_omit_kube"
PACKAGECONFIG[ssh] = "ts_ssh,ts_omit_ssh"
PACKAGECONFIG[tap] = "ts_tap,ts_omit_tap"
PACKAGECONFIG[wakeonlan] = "ts_wakeonlan,ts_omit_wakeonlan"

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "tailscaled.service tailscale-webui.service tailscale-certs.service tailscale-certs.timer"

do_install() {
	install -d ${D}/${sbindir}
	install -m 0755 ${B}/${GO_BUILD_BINDIR}/tailscaled ${D}/${sbindir}/tailscaled

	if [ "${@bb.utils.contains('PACKAGECONFIG', 'cli', 'true', 'false', d)}" = 'true' ]; then
		install -d ${D}/${bindir}
		ln -sr ${D}${sbindir}/tailscaled ${D}${bindir}/tailscale
	fi

	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		install -d ${D}${systemd_system_unitdir}
		install -m 644 ${WORKDIR}/tailscaled.service ${D}${systemd_system_unitdir}/tailscaled.service
		install -m 644 ${WORKDIR}/tailscale-webui.service ${D}${systemd_system_unitdir}/tailscale-webui.service
		install -m 644 ${WORKDIR}/tailscale-certs.service ${D}${systemd_system_unitdir}/tailscale-certs.service
		install -m 644 ${WORKDIR}/tailscale-certs.timer ${D}${systemd_system_unitdir}/tailscale-certs.timer
	fi

	install -d ${D}${libexecdir}
	install -m 0755 ${WORKDIR}/tailscale-certs.sh ${D}${libexecdir}/tailscale-certs.sh

	install -d -o tailscale -g tailscale -m 0750 ${D}${sysconfdir}/certs/tailscale
	install -d -m 0700 ${D}${localstatedir}/tailscale
}

FILES:${PN}-src += "${libdir}/go/src"
FILES:${PN} += "${libexecdir}/tailscale-certs.sh ${sysconfdir}/certs/tailscale ${localstatedir}/tailscale"

RDEPENDS:${PN} = "iptables ${@bb.utils.contains('PACKAGECONFIG', 'completion', 'bash-completion', '', d)}"

RRECOMMENDS:${PN} = "\
	kernel-module-wireguard \
	kernel-module-tun \
	kernel-module-xt-mark \
	kernel-module-xt-tcpudp \
	kernel-module-xt-masquerade"
