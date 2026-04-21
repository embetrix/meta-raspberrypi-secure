# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# AVB/DM-Verity support:
#   IMAGE_FSTYPES conversion that appends an AVB hashtree footer to a
#   filesystem image using avbtool.  The footer is placed right after
#   the filesystem (--partition_size 0) so that avb_verify can scan
#   for it and set up dm-verity via dmsetup at runtime.
inherit image_types

DEPENDS += "avbtool-native openssl-native"
CONVERSIONTYPES += "avbverity"

WICVARS:append = " AVB_SIGN_KEY AVB_ALGORITHM AVB_HASH_ALGORITHM AVB_ROOTHASH_SIG AVB_X509"

# Default AVB settings
AVB_ALGORITHM ?= "SHA256_RSA4096"
AVB_HASH_ALGORITHM ?= "sha256"
AVB_PARTITION_NAME ?= "rootfs"

# Enable PKCS#7 root hash signature (for dm-verity root_hash_sig_key_desc)
# Uses AVB_SIGN_KEY and AVB_X509 when set to "1"
AVB_ROOTHASH_SIG ?= "1"

# Partition size for avbtool (bytes):  Default 0 = auto-size the partition
# to fit the image + hashtree + footer exactly.  Override to set an explicit
# fixed partition size (must be larger than the image)
AVB_PARTITION_SIZE ?= "0"

# dm-verity uses 4096-byte data blocks; the filesystem block size
# must match or the kernel will refuse to mount.
EXTRA_IMAGECMD:ext4:append = " -b 4096"

avb_verity_setup() {

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

    cp $IMAGE_IN $IMAGE_OUT
    avbtool add_hashtree_footer \
        --image $IMAGE_OUT \
        --partition_name ${AVB_PARTITION_NAME} \
        --partition_size ${AVB_PARTITION_SIZE} \
        --algorithm ${AVB_ALGORITHM} \
        --key ${AVB_SIGN_KEY} \
        --hash_algorithm ${AVB_HASH_ALGORITHM} \
        --do_not_generate_fec

    if [ "${AVB_ROOTHASH_SIG}" = "1" ]; then
        ROOT_HASH=$(avbtool info_image --image $IMAGE_OUT \
            | sed -n 's/.*Root Digest:[[:space:]]*//p')
        SALT=$(avbtool info_image --image $IMAGE_OUT \
            | sed -n 's/.*Salt:[[:space:]]*//p')
        # Kernel passes root hash as hex string to verify_pkcs7_signature
        echo -n "$ROOT_HASH" > ${WORKDIR}/roothash.hex

        openssl smime -sign -binary -noattr -nocerts \
            -in ${WORKDIR}/roothash.hex \
            -inkey ${AVB_SIGN_KEY} -signer ${AVB_X509} \
            -outform der -out ${WORKDIR}/roothash.p7s

        avbtool erase_footer --image $IMAGE_OUT
        avbtool add_hashtree_footer \
            --image $IMAGE_OUT \
            --partition_name ${AVB_PARTITION_NAME} \
            --partition_size ${AVB_PARTITION_SIZE} \
            --algorithm ${AVB_ALGORITHM} \
            --key ${AVB_SIGN_KEY} \
            --hash_algorithm ${AVB_HASH_ALGORITHM} \
            --salt ${SALT} \
            --do_not_generate_fec \
            --prop_from_file roothash_sig:${WORKDIR}/roothash.p7s
    fi
}

CONVERSION_CMD:avbverity = "avb_verity_setup ${IMAGE_NAME}.${type} ${IMAGE_NAME}.${type}.avbverity"
CONVERSION_DEPENDS_avbverity = "avbtool-native openssl-native"
