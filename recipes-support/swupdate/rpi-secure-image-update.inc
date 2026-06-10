LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
SECTION = "swupdate"

inherit swupdate

# SWU_IMAGE: the Yocto image this compound update is built around.
# Derived from the recipe name by stripping the "-update" suffix
# (e.g. rpi-secure-image-base-update -> rpi-secure-image-base).
# A recipe may still override it explicitly before the require.
SWU_IMAGE ?= "${@d.getVar('PN').replace('-update', '')}"

# Note: sw-description is mandatory
SRC_URI = "file://sw-description"
IMAGE = "${SWU_IMAGE}"

# IMAGE_DEPENDS: list of Yocto images that contains a root filesystem
# it will be ensured they are built before creating swupdate image
IMAGE_DEPENDS = "${SWU_IMAGE}"

# SWUPDATE_IMAGES: list of images that will be part of the compound image
# the list can have any binaries and images must be in the DEPLOY directory
SWUPDATE_IMAGES += " boot-signed"
SWUPDATE_IMAGES += "${SWU_IMAGE}"

SWUPDATE_IMAGES_FSTYPES[boot-signed] = ".tar.gz"
SWUPDATE_IMAGES_ENCRYPTED[boot-signed] = "1"

# The per-image varflags below are keyed by the image name. BitBake does NOT
# expand ${SWU_IMAGE} inside a varflag key, so set them via setVarFlag where
# SWU_IMAGE resolves to the real name. The ${MACHINE}/${ROOTFS_TYPE} in the
# fstype value stay raw on purpose: the swupdate class reads the flag with
# expand=True and resolves them at consume time.
python () {
    img = d.getVar('SWU_IMAGE')
    if not img:
        bb.fatal("SWU_IMAGE must be set before requiring rpi-secure-image-update.inc")
    # Images can have multiple formats  define which image must be
    # taken to be put in the compound image
    d.setVarFlag('SWUPDATE_IMAGES_FSTYPES', img, '-${MACHINE}.rootfs.${ROOTFS_TYPE}.avbverity.gz')
    d.setVarFlag('SWUPDATE_IMAGES_ENCRYPTED', img, '1')
}

do_swuimage[nostamp] = "1"

# Also build the standalone EEPROM-only update alongside the rootfs/boot
# compound image. The two .swu files are applied separately so the EEPROM
# recovery flash does not consume the rootfs A/B tryboot one-shot.
do_build[depends] += "rpi-eeprom-update:do_build"
