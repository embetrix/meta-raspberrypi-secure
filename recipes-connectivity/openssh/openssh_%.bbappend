FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://authorized_keys"

SSH_USER ?= "myadmin"

do_install:append() {
    install -d -m 0700 ${D}/home/${SSH_USER}/.ssh
    install -m 0644 ${WORKDIR}/authorized_keys ${D}/home/${SSH_USER}/.ssh/authorized_keys
}

FILES:${PN} += "/home/${SSH_USER}/.ssh"
