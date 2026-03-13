################################################################################
#
# rpi-secure.inc: security hardening for Raspberry Pi
#
################################################################################

# Enforce baseline compiler/linker hardening flags for C/C++ and Rust
require conf/distro/include/security_flags.inc
require conf/distro/include/rust_security_flags.inc

# Enable security related distro features
DISTRO_FEATURES += "ima integrity security"

# Root login
EXTRA_IMAGE_FEATURES:remove = " debug-tweaks"

##############################################################
# Kernel module signing
##############################################################
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: Debug keys to replace with production keys before deployment
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
MODSIGN_KEY_DIR  = "${INTEGRITY_BASE}/data/debug-keys"
MODSIGN_PRIVKEY ?= "${MODSIGN_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509    ?= "${MODSIGN_KEY_DIR}/x509_modsign.crt"

##############################################################
# IMA/EVM file signing
##############################################################
INHERIT += "ima-evm-rootfs"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: Debug keys to replace with production keys before deployment
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
IMA_EVM_KEY_DIR = "${INTEGRITY_BASE}/data/debug-keys"
IMA_EVM_PRIVKEY ?= "${IMA_EVM_KEY_DIR}/privkey_ima.pem"
IMA_EVM_X509 ?= "${IMA_EVM_KEY_DIR}/x509_ima.der"

##############################################################
# Extra packages
##############################################################
MACHINE_EXTRA_RDEPENDS += "usbguard iptables"

##############################################################
# Device tree hardening
##############################################################
# Keep only the DTB and overlays required by the actual hardware
# to reduce kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
