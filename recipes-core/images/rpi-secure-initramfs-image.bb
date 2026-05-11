DESCRIPTION = "Raspberry Pi secure initramfs image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

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

IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"
