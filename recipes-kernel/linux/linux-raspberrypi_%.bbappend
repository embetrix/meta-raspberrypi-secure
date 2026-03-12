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
# NOTE: These are debug/development keys and MUST be replaced
# with your own production keys before deploying to the field.
MODSIGN_KEY_DIR  = "${INTEGRITY_BASE}/data/debug-keys"
MODSIGN_PRIVKEY ?= "${MODSIGN_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509    ?= "${MODSIGN_KEY_DIR}/x509_modsign.crt"
