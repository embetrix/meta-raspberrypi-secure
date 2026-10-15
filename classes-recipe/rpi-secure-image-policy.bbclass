# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# Loaded through IMAGE_CLASSES by rpi-secure-distro.inc for regular images.
# Account creation and passwords remain the responsibility of each image.

IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

# Save IMA/EVM signature manifests in the root filesystem.
IMA_FILE_SIGNATURES_FILE ?= "etc/ima-signatures.manifest"
EVM_FILE_SIGNATURES_FILE ?= "etc/evm-signatures.manifest"

IMAGE_INSTALL:append = " \
    packagegroup-security-base \
    packagegroup-swupdate \
    ${@bb.utils.contains('RPI_SECURITY_PROFILE', 'dev', 'packagegroup-dev', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ima', 'packagegroup-ima-evm', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'selinux', 'packagegroup-selinux', '', d)} \
    "
