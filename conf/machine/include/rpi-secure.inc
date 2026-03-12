# rpi-secure.inc: Machine-level security hardening for Raspberry Pi
#
# This include is loaded by meta-raspberrypi-secure's layer.conf and
# applies to all builds that use this layer. It enables IMA/EVM
# integrity, kernel module signing and default-deny USB policy.

# Enable security related distro features
DISTRO_FEATURES += "ima integrity security harden"

##############################################################
# Kernel module signing
##############################################################
# WARNING: Debug keys to replace with production keys before deployment
MODSIGN_KEY_DIR  = "${INTEGRITY_BASE}/data/debug-keys"
MODSIGN_PRIVKEY ?= "${MODSIGN_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509    ?= "${MODSIGN_KEY_DIR}/x509_modsign.crt"

##############################################################
# IMA/EVM file signing
##############################################################
INHERIT += "ima-evm-rootfs"
# WARNING: Debug keys to replace with production keys before deployment
IMA_EVM_KEY_DIR = "${INTEGRITY_BASE}/data/debug-keys"
IMA_EVM_PRIVKEY ?= "${IMA_EVM_KEY_DIR}/privkey_ima.pem"
IMA_EVM_X509 ?= "${IMA_EVM_KEY_DIR}/x509_ima.der"

##############################################################
# Extra packages
##############################################################
MACHINE_EXTRA_RDEPENDS += "usbguard"

