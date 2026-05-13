FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Enable Kernel modules signing
inherit kernel-modsign

# Stage IMA/EVM & AVB_X509 x509 for CONFIG_SYSTEM_TRUSTED_KEYS
KERNEL_TRUSTED_KEYS = "${AVB_X509} ${IMA_EVM_X509}"
inherit kernel-trusted-keys

SRC_URI += " \
            file://patches/v6.12/0002-dm-verity-add-CONFIG_DM_VERITY_REQUIRE_ROOTHASH_SIG.patch \
            file://dm-crypt-verity.cfg \
            file://ext4.cfg \
            file://erofs.cfg \
            file://squashfs.cfg \
            file://ima-evm.cfg \
            file://kmod-sign.cfg \
            file://hwrng.cfg \
            file://netfilter.cfg \
            file://crypto.cfg \
            ${@bb.utils.contains('MACHINE_FEATURES', 'wifi', '', 'file://no-wifi.cfg', d)} \
            ${@bb.utils.contains('MACHINE_FEATURES', 'bluetooth', '', 'file://no-bluetooth.cfg', d)} \
            ${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'file://tpm.cfg', '', d)} \
            ${@bb.utils.contains('DISTRO_FEATURES', 'selinux', 'file://selinux.cfg', '', d)} \
            ${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.cfg', '', d)} \
            "
