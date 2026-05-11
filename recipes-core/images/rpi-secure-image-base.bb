DESCRIPTION = "Raspberry Pi secure base image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit core-image extrausers

IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

# save IMA/EVM signatures as fingerints for rootfs
IMA_FILE_SIGNATURES_FILE = "etc/ima-signatures.manifest"
EVM_FILE_SIGNATURES_FILE = "etc/evm-signatures.manifest"

#
# Generate your password hash(es) with: 
# $ openssl passwd -5 -salt "$(openssl rand -hex 8)" 'some_very_secure_password' | sed 's/\$/\\$/g'
# Default passwords for :
# 'rpi'  : 'notrustnofun' (non admin user)
# 'root' : '1234butbetter'
#
# NOTE: On the 'prod' profile, SSH/Serial password login is disabled
# Only certificate-based authentication is allowed over SSH
#
RPI_USER_PASSWD_HASH  ?= "\$5\$ae3c3495942cbc3b\$PKEnZIPY2QldtV2ExeTafSRpuMAgjLL4NEw74RPPxp/"
ROOT_USER_PASSWD_HASH ?= "\$5\$8fe9b3c5b1479874\$kZwSJoxUOIHpuJRVts0Th4ueQPEJ2A0T7o3a3Fn92a4"

EXTRA_USERS_PARAMS = " \
    useradd -m -s /bin/sh rpi; \
    usermod -p '${RPI_USER_PASSWD_HASH}'  rpi;  \
    usermod -p '${ROOT_USER_PASSWD_HASH}' root; \
    "

IMAGE_INSTALL += " \
	packagegroup-security-base \
	"

IMAGE_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'ima', "packagegroup-ima-evm", '', d)}"
IMAGE_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'selinux', "packagegroup-selinux", '', d)}"

IMAGE_INSTALL += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'dev', "packagegroup-dev", '', d)}"
