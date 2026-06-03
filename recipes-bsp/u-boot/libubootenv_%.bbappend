FILESEXTRAPATHS:prepend := "${THISDIR}/libubootenv:"

SRC_URI:append:rpi = " file://fw_env.config"

do_install:append:rpi() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/fw_env.config ${D}${sysconfdir}/fw_env.config
    ln -sf /dev/null ${D}${sysconfdir}/u-boot-initial-env
}

FILES:${PN}-bin:append:rpi = " ${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
CONFFILES:${PN}-bin:append:rpi = " ${sysconfdir}/fw_env.config"
