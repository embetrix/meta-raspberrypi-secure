FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://authorized_keys"

SSH_USER ?= "myadmin"

# Create myadmin in pseudo's fakeroot so chown works at do_install time.
# openssh already inherits useradd; we append our user to it.
USERADD_PACKAGES:append = " ${PN}"
USERADD_PARAM:${PN} = "-m -s /bin/sh ${SSH_USER}"
GROUPADD_PARAM:${PN} = "wheel"

do_install:append() {
    install -d -m 0700 ${D}/home/${SSH_USER}/.ssh
    install -m 0600 ${WORKDIR}/authorized_keys ${D}/home/${SSH_USER}/.ssh/authorized_keys
    chown -R ${SSH_USER}:${SSH_USER} ${D}/home/${SSH_USER}/.ssh
}

FILES:${PN} += "/home/${SSH_USER}/.ssh"
