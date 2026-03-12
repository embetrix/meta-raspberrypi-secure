FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://dm-crypt-verity.cfg \
            file://ima-evm.cfg \
            file://kmod-sign.cfg \
            file://netfilter.cfg \
            file://security-harden.cfg \
            "

SRC_URI += "${@bb.utils.contains('DISTRO_FEATURES', 'wifi', '', 'file://no-wifi.cfg', d)}"
SRC_URI += "${@bb.utils.contains('DISTRO_FEATURES', 'bluetooth', '', 'file://no-bluetooth.cfg', d)}"

# Enable Kernel modules signing
inherit kernel-modsign

