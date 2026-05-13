FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://watchdog.cfg \
            ${@bb.utils.contains('DISTRO_FEATURES', 'selinux', 'file://selinux.cfg', '', d)} \
            ${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.cfg', '', d)} \
            "
