FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Enable Kernel modules signing
inherit kernel-modsign

# Stage IMA/EVM x509 for CONFIG_SYSTEM_TRUSTED_KEYS
KERNEL_TRUSTED_KEYS = "${AVB_X509} ${IMA_EVM_X509} ${MODSIGN_X509}"
inherit kernel-trusted-keys

SRC_URI += "file://patches/v6.6/0001-security-keys-add-rpi-firmware-crypto-trusted-key-so.patch \
            file://patches/v6.6/0002-dm-verity-add-CONFIG_DM_VERITY_REQUIRE_ROOTHASH_SIG.patch \
            file://dm-crypt-verity.cfg \
            file://ext4.cfg \
            file://erofs.cfg \
            file://squashfs.cfg \
            file://ima-evm.cfg \
            file://kmod-sign.cfg \
            file://hwrng.cfg \
            file://netfilter.cfg \
            file://crypto.cfg \
            "

SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'wifi', '', 'file://no-wifi.cfg', d)}"
SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'bluetooth', '', 'file://no-bluetooth.cfg', d)}"

# TPM support 
SRC_URI += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'file://tpm.cfg', '', d)}"

SRC_URI += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'file://security-harden.cfg', '', d)}"
