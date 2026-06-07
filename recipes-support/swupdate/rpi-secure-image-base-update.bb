DESCRIPTION = "rpi secure base image swupdate compound image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
SECTION = "swupdate"

inherit swupdate

# Note: sw-description is mandatory
SRC_URI = "file://sw-description"
IMAGE = "rpi-secure-image-base"
IMAGE_FSTYPES += "${ROOTFS_TYPE}.avbverity.gz"

# IMAGE_DEPENDS: list of Yocto images that contains a root filesystem
# it will be ensured they are built before creating swupdate image
IMAGE_DEPENDS = "rpi-secure-image-base"

SWUPDATE_IMAGES += " boot.img boot.sig"

# SWUPDATE_IMAGES: list of images that will be part of the compound image
# the list can have any binaries - images must be in the DEPLOY directory
SWUPDATE_IMAGES += "rpi-secure-image-base"

# Images can have multiple formats - define which image must be
# taken to be put in the compound image
SWUPDATE_IMAGES_FSTYPES[rpi-secure-image-base] = "-${MACHINE}.rootfs.${ROOTFS_TYPE}.avbverity.gz"

do_rootfs[nostamp] = "1"
