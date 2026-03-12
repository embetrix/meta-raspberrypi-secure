FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://authorized_keys"

# Default admin account created by meta-hardening
SSH_USER ?= "myadmin"

do_install:append() {
    install -d -m 0700 ${D}/home/${SSH_USER}/.ssh
    install -m 0600 ${WORKDIR}/authorized_keys ${D}/home/${SSH_USER}/.ssh/authorized_keys
    chown -R ${SSH_USER}:${SSH_USER} ${D}/home/${SSH_USER}/.ssh
}

FILES:${PN} += "/home/${SSH_USER}/.ssh"
