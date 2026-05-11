DESCRIPTION = "packagegroup for Selinux support"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
                    file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

PACKAGE_ARCH = "${TUNE_PKGARCH}"

inherit packagegroup

PACKAGES = "${PN}"

SUMMARY:packagegroup-selinux = "Selinux support"

RDEPENDS:packagegroup-selinux = " \
	libsepol \
	libselinux \
	libselinux-bin \
	libsemanage \
	policycoreutils-fixfiles \
	policycoreutils-secon \
	policycoreutils-semodule \
	policycoreutils-sestatus \
	policycoreutils-setfiles \
	refpolicy \
   "
