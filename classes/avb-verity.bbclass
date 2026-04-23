# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# AVB/DM-Verity support:
#   IMAGE_FSTYPES conversion that appends an AVB hashtree footer to a
#   filesystem image using avbtool.  The footer is placed right after
#   the filesystem (--partition_size 0) so that avb_verify can scan
#   for it and set up dm-verity via dmsetup at runtime.
inherit image_types

DEPENDS += "avb-utils-native"
CONVERSIONTYPES += "avbverity"

WICVARS:append = " AVB_SIGN_KEY AVB_ALGORITHM AVB_HASH_ALGORITHM AVB_ROOTHASH_SIG AVB_X509"

# Default AVB settings
AVB_ALGORITHM ?= "SHA256_RSA4096"
AVB_HASH_ALGORITHM ?= "sha256"
AVB_PARTITION_NAME ?= "rootfs"

# Partition size for avbtool (bytes):  Default 0 = auto-size the partition
# to fit the image + hashtree + footer exactly.  Override to set an explicit
# fixed partition size (must be larger than the image)
AVB_PARTITION_SIZE ?= "0"

# dm-verity uses 4096-byte data blocks; the filesystem block size
# must match or the kernel will refuse to mount.
EXTRA_IMAGECMD:ext4:append = " -b 4096"

avbverity_setup() {

    IMAGE_IN=$1
    IMAGE_OUT=$2

    if [ ! -f "${AVB_SIGN_KEY}" ]; then
        bbfatal "AVB sign key not found: ${AVB_SIGN_KEY}"
    fi

    if [ "${AVB_ROOTHASH_SIG}" = "1" ]; then
        if [ ! -f "${AVB_X509}" ]; then
            bbfatal "AVB X.509 cert not found: ${AVB_X509}"
        fi
    fi

    avb_sign \
        --image  "${IMAGE_IN}" \
        --output "${IMAGE_OUT}" \
        --key    "${AVB_SIGN_KEY}" \
        --cert   "${AVB_X509}" \
        --partition-name "${AVB_PARTITION_NAME}" \
        --algorithm "${AVB_ALGORITHM}"
}

CONVERSION_CMD:avbverity = "avbverity_setup ${IMAGE_NAME}.${type} ${IMAGE_NAME}.${type}.avbverity"
CONVERSION_DEPENDS_avbverity = "avb-utils-native"
