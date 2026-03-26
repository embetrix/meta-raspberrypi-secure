DESCRIPTION = "Raspberry Pi secure initramfs image"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

PACKAGE_INSTALL = "rpi-secure-initramfs-init \
                   base-files base-passwd \
                   ${VIRTUAL-RUNTIME_base-utils} \
                   ${ROOTFS_BOOTSTRAP_INSTALL} \
                "

inherit core-image

# Do not pollute the initrd image with rootfs features
IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""

# Do not install RRECOMMENDS
NO_RECOMMENDATIONS = "1"

# save IMA/EVM signatures to manifest files
REQUIRED_DISTRO_FEATURES += "ima"
IMA_FILE_SIGNATURES_FILE = "etc/ima-signatures.manifest"
EVM_FILE_SIGNATURES_FILE = "etc/evm-signatures.manifest"

IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"
