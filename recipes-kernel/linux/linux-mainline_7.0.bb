DESCRIPTION = "Mainline Linux kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"
inherit kernel

S = "${WORKDIR}/git"
SRC_URI = "git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git;branch=master;protocol=https"
SRCREV = "028ef9c96e96197026887c0f092424679298aae8"
PV = "${PN}"
PROVIDES = "virtual/kernel"

SRC_URI += "file://defconfig \
            file://0001-security-keys-add-rpi-firmware-crypto-trusted-key-so.patch \
            "

# Stage IMA/EVM x509 for CONFIG_SYSTEM_TRUSTED_KEYS
KERNEL_TRUSTED_KEYS = "${AVB_X509} ${IMA_EVM_X509} ${MODSIGN_X509}"
inherit kernel-trusted-keys

# Enable Kernel modules signing
inherit kernel-modsign