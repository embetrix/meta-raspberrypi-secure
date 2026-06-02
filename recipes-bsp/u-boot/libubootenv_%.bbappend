FILESEXTRAPATHS:prepend := "${THISDIR}/libubootenv:"

SRC_URI += "file://fw_env.config \
            file://u-boot-initial-env"

do_install:append() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/fw_env.config      ${D}${sysconfdir}/fw_env.config
    install -m 0644 ${UNPACKDIR}/u-boot-initial-env ${D}${sysconfdir}/u-boot-initial-env
}

# fw_printenv/fw_setenv live in libubootenv-bin, so the config and the default
# environment (seed used when the raw env has no valid CRC) belong there.
FILES:${PN}-bin     += "${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
CONFFILES:${PN}-bin += "${sysconfdir}/fw_env.config ${sysconfdir}/u-boot-initial-env"
