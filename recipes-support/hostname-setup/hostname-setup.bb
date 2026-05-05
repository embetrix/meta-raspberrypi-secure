DESCRIPTION = "hostname setup"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

inherit systemd

SRC_URI = "file://hostname-setup.service"
SRC_URI += "file://hostname-setup.sh"

SYSTEMD_SERVICE:${PN} = "hostname-setup.service"
SYSTEMD_PACKAGES = "${PN}"

do_install() {

	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/hostname-setup.sh ${D}${bindir}/hostname-setup
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${WORKDIR}/hostname-setup.service ${D}${systemd_unitdir}/system/
}
