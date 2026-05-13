DESCRIPTION = "Raspberry Pi secure demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

require recipes-core/images/rpi-secure-image-base.bb

IMAGE_INSTALL += " \
	rpi-device-certs \
    open62541 \
	"
