FILESEXTRAPATHS:prepend := "${THISDIR}/libubootenv:"

SRC_URI:append:rpi = " file://fw_env.config \
                       file://u-boot-initial-env"

do_install:append:rpi() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/fw_env.config      ${D}${sysconfdir}/fw_env.config
    install -m 0644 ${UNPACKDIR}/u-boot-initial-env ${D}${sysconfdir}/u-boot-initial-env
}

FILES:${PN}-bin:append:rpi = " ${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
CONFFILES:${PN}-bin:append:rpi = " ${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
