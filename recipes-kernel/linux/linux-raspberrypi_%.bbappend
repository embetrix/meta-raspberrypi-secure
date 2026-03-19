FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://dm-crypt-verity.cfg \
            file://ext4.cfg \
            file://erofs.cfg \
            file://ima-evm.cfg \
            file://kmod-sign.cfg \
            file://netfilter.cfg \
            "

SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'file://no-tpm.cfg', '', d)}"
SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'wifi', '', 'file://no-wifi.cfg', d)}"
SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'bluetooth', '', 'file://no-bluetooth.cfg', d)}"

SRC_URI += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.cfg', '', d)}"

# Enable Kernel modules signing
inherit kernel-modsign

