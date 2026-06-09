DESCRIPTION = "EEPROM-only swupdate compound image (decoupled from rootfs A/B)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
SECTION = "swupdate"

inherit swupdate

# Image that produces the signed EEPROM artifacts in DEPLOY_DIR_IMAGE
IMAGE_DEPENDS = "rpi-secure-image-base rpi-eeprom"

SRC_URI = "file://sw-description"  

SWUPDATE_IMAGES = "pieeprom.bin.signed pieeprom.upd.sig recovery.bin"
SWUPDATE_IMAGES_ENCRYPTED[pieeprom.bin.signed] = "1"
SWUPDATE_IMAGES_ENCRYPTED[pieeprom.upd.sig]    = "1"
SWUPDATE_IMAGES_ENCRYPTED[recovery.bin]        = "1"

do_swuimage[nostamp] = "1"
