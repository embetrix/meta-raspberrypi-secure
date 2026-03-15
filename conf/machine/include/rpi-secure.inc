
# Firmware Boot
DISABLE_SPLASH = "1"
RPI_EXTRA_CONFIG = "init_uart_baud=0\ndtparam=watchdog=on\n"

# Console Policy
SERIAL_CONSOLES = ""
CMDLINE:append = " console=null quiet loglevel=0 ro"

# Boot Artifacts
# Ship the bundled kernel+initramfs image as the firmware-loaded kernel.
IMAGE_BOOT_FILES += "${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin;${SDIMG_KERNELIMAGE}"

# Device Tree Hardening
# Keep only the DTB and overlays required by the actual hardware.
# This reduces the kernel attack surface.
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""

# Image Policy
EXTRA_IMAGE_FEATURES:remove = "debug-tweaks"

# Initramfs Bundling
INITRAMFS_IMAGE  = "initramfs-image"
INITRAMFS_IMAGE_NAME = "initramfs-image-${MACHINE}.rootfs"
INITRAMFS_IMAGE_BUNDLE = "1"

# Raspberry Pi Secure Boot
IMAGE_CLASSES += "rpi-secure-boot"
RPI_SECURE_BOOT_SIGN = "1"
RPI_SECURE_BOOT_SIGN_KEY_GEN = "1"
IMAGE_BOOT_FILES += "boot.img boot.sig"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: Debug keys to replace with production keys before deployment
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# RPI_SECURE_BOOT_SIGN_KEY = "/path/to/keys/secure-boot-sign.key"

# Kernel Module Signing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: Debug keys to replace with production keys before deployment
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
MODSIGN_KEY_DIR  = "${INTEGRITY_BASE}/data/debug-keys"
MODSIGN_PRIVKEY ?= "${MODSIGN_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509    ?= "${MODSIGN_KEY_DIR}/x509_modsign.crt"

# IMA/EVM Rootfs Signing
INHERIT += "ima-evm-rootfs"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: Debug keys to replace with production keys before deployment
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
IMA_EVM_KEY_DIR = "${INTEGRITY_BASE}/data/debug-keys"
IMA_EVM_PRIVKEY ?= "${IMA_EVM_KEY_DIR}/privkey_ima.pem"
IMA_EVM_X509 ?= "${IMA_EVM_KEY_DIR}/x509_ima.der"

# Runtime Packages
MACHINE_EXTRA_RRECOMMENDS += "\
    usbguard \
    rpi-config \
    rpi-eeprom \
    raspi-utils \
    "
