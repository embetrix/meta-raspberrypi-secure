FILESEXTRAPATHS:prepend := "${THISDIR}/libubootenv:"

SRC_URI += "file://fw_env.config"

do_install:append() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/fw_env.config ${D}${sysconfdir}/fw_env.config
}

# fw_printenv/fw_setenv live in libubootenv-bin, so the config belongs there
FILES:${PN}-bin     += "${sysconfdir}/fw_env.config"
CONFFILES:${PN}-bin += "${sysconfdir}/fw_env.config"
