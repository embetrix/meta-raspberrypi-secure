FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://watchdog.cfg \
            ${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.cfg', '', d)} \
            "

# Disable syslog applet as it is not used and causes build issues
SRC_URI:remove = "file://syslog.cfg"
