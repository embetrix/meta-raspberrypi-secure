# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# Original reference:
#   https://github.com/agherzan/meta-raspberrypi/blob/master/classes/sdcard_image-rpi.bbclass
#
# This class tries to mimic sdcard_image-rpi.bbclass but generates only boot.img
# instead of a full SD card image with rootfs partition.
# It creates a standalone bootable FAT32 partition image containing
# bootloader files, kernel, device trees, and overlays.
# When secure boot is enabled, it also generates a signature file boot.sig along side with boot.img
#
# Usage:
#   To enable this class add in distro config or local.conf:
#   IMAGE_CLASSES += "rpi-secure-boot"
#
#   RPI_SECURE_BOOT_SIGN = "1"
#   RPI_SECURE_BOOT_SIGN_KEY = "/path/to/keys/secure-boot-sign.key"
#
#   Key generation for dev builds is handled by the rpi-signing-keys class.
#
#   To deploy boot.img/boot.sig to the boot partition via wic add:
#   IMAGE_BOOT_FILES += "boot.img boot.sig"
#   This remains backward compatible when secure boot signing is disabled.
#
#   For strict secure boot usage:
#   IMAGE_BOOT_FILES = "boot.img boot.sig"
#

inherit image_types signing

# Enable signing of boot.img in deploy directory.
RPI_SECURE_BOOT_SIGN ?= "0"
RPI_SECURE_BOOT_SIGN_KEY ?= ""

# Fixed signing timestamp in epoch for reproducible builds
RPI_SECURE_BOOT_SIGN_TIMESTAMP ?= "${SOURCE_DATE_EPOCH}"

# Space-separated list of files to remove from boot.img after it is populated
SECURE_BOOT_FILES_EXCLUDE ?= ""

# Boot FAT size in KiB for the standalone boot.img.
# Keep this larger than the sdcard_image-rpi default to leave room for
# bundled initramfs kernels and Raspberry Pi firmware files.
RPI_SECURE_BOOT_SPACE ?= "131072"

# Boot image/signature name
RPI_SECURE_BOOTIMG = "${DEPLOY_DIR_IMAGE}/boot.img"
RPI_SECURE_BOOTIMG_SIG = "${DEPLOY_DIR_IMAGE}/boot.sig"
RPI_SECURE_BOOT_CONFIG = "${DEPLOY_DIR_IMAGE}/bootconf.txt"
RPI_SECURE_BOOT_CONFIG_SIG = "${DEPLOY_DIR_IMAGE}/bootconf.sig"
RPI_SECURE_BOOT_EEPROM = "${DEPLOY_DIR_IMAGE}/pieeprom.bin"
RPI_SECURE_BOOT_EEPROM_SIG = "${DEPLOY_DIR_IMAGE}/pieeprom.bin.sig"
RPI_SECURE_BOOT_EEPROM_SIGNED = "${DEPLOY_DIR_IMAGE}/pieeprom.bin.signed"

do_image_rpi_secure_boot[depends] = " \
    mtools-native:do_populate_sysroot \
    dosfstools-native:do_populate_sysroot \
    virtual/kernel:do_deploy \
    rpi-bootfiles:do_deploy \
    ${@bb.utils.contains('RPI_SECURE_BOOT_SIGN', '1', 'openssl-native:do_populate_sysroot', '', d)} \
    ${@bb.utils.contains('RPI_SECURE_BOOT_SIGN', '1', 'rpi-eeprom-native:do_populate_sysroot', '', d)} \
    ${@bb.utils.contains('RPI_SECURE_BOOT_SIGN', '1', 'rpi-eeprom:do_deploy', '', d)} \
    ${@bb.utils.contains('MACHINE_FEATURES', 'armstub', 'armstubs:do_deploy', '' ,d)} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'u-boot:do_deploy', '',d)} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'u-boot-default-script:do_deploy', '',d)} \
"

do_image_rpi_secure_boot[recrdeps] = "do_build"

# Ensure wic images depend on rpi-secure-boot image type when both are enabled.
IMAGE_TYPEDEP:wic += " rpi-secure-boot"

IMAGE_CMD:rpi-secure-boot () {

    # Check if we are building with device tree support
    DTS="${@make_dtb_boot_files(d)}"

    # Stage all boot files into a temporary directory to calculate size
    BOOT_STAGING="${WORKDIR}/boot-staging"
    rm -rf "${BOOT_STAGING}"
    mkdir -p "${BOOT_STAGING}"

    cp -a ${DEPLOY_DIR_IMAGE}/${BOOTFILES_DIR_NAME}/* "${BOOT_STAGING}/"
    if [ "${@bb.utils.contains("MACHINE_FEATURES", "armstub", "1", "0", d)}" = "1" ]; then
        cp ${DEPLOY_DIR_IMAGE}/armstubs/${ARMSTUB} "${BOOT_STAGING}/"
    fi
    if test -n "${DTS}"; then
        mkdir -p "${BOOT_STAGING}/overlays"
        for entry in ${DTS} ; do
            if [ $(echo "$entry" | grep -c \;) = "0" ] ; then
                DEPLOY_FILE="$entry"
                DEST_FILENAME="$entry"
            else
                DEPLOY_FILE="$(echo "$entry" | cut -f1 -d\;)"
                DEST_FILENAME="$(echo "$entry" | cut -f2- -d\;)"
            fi
            cp ${DEPLOY_DIR_IMAGE}/${DEPLOY_FILE} "${BOOT_STAGING}/${DEST_FILENAME}"
        done
    fi
    if [ "${RPI_USE_U_BOOT}" = "1" ]; then
        cp ${DEPLOY_DIR_IMAGE}/u-boot.bin "${BOOT_STAGING}/${SDIMG_KERNELIMAGE}"
        cp ${DEPLOY_DIR_IMAGE}/boot.scr "${BOOT_STAGING}/boot.scr"
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            cp ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin "${BOOT_STAGING}/${KERNEL_IMAGETYPE}"
        else
            cp ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} "${BOOT_STAGING}/${KERNEL_IMAGETYPE}"
        fi
    else
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            cp ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin "${BOOT_STAGING}/${SDIMG_KERNELIMAGE}"
        else
            cp ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} "${BOOT_STAGING}/${SDIMG_KERNELIMAGE}"
        fi
    fi

    # Exclude files if specified
    if [ -n "${SECURE_BOOT_FILES_EXCLUDE}" ]; then
        for entry in ${SECURE_BOOT_FILES_EXCLUDE} ; do
            rm -f "${BOOT_STAGING}/${entry}"
        done
    fi

    # Calculate image size from staged content
    NEEDED_KB=$(du -sk "${BOOT_STAGING}" | awk '{print $1}')
    # Add FAT32 overhead (~1 MiB metadata) and 10% margin
    BOOT_SIZE_KB=$(expr $NEEDED_KB + $NEEDED_KB / 10 + 1024)
    # FAT32 minimum is ~33 MiB (65525 clusters)
    if [ ${BOOT_SIZE_KB} -lt 33792 ]; then
        BOOT_SIZE_KB=33792
    fi
    # Align to 1 MiB
    BOOT_SIZE_KB=$(expr \( $BOOT_SIZE_KB + 1023 \) / 1024 \* 1024)
    # Cap to RPI_SECURE_BOOT_SPACE
    if [ ${BOOT_SIZE_KB} -gt ${RPI_SECURE_BOOT_SPACE} ]; then
        bbfatal "Boot content (${BOOT_SIZE_KB} KiB) exceeds RPI_SECURE_BOOT_SPACE (${RPI_SECURE_BOOT_SPACE} KiB)"
    fi
    bbnote "Creating boot.img: ${BOOT_SIZE_KB} KiB (content: ${NEEDED_KB} KiB, max: ${RPI_SECURE_BOOT_SPACE} KiB)"

    # Create and populate boot.img
    rm -f ${WORKDIR}/boot.img
    mkfs.vfat -F32 -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img ${BOOT_SIZE_KB}
    mcopy -s -i ${WORKDIR}/boot.img "${BOOT_STAGING}"/* ::/ || bbfatal "mcopy failed to populate boot.img"
    rm -rf "${BOOT_STAGING}"

    cp ${WORKDIR}/boot.img ${RPI_SECURE_BOOTIMG}

    # Generate signature file if secure boot enabled
    # The signature format is :
    # <sha256-hex>
    # ts: <unix-epoch-seconds>
    # rsa2048: <rsa-pkcs1v1.5-sha256-signature-hex>
    if [ "${RPI_SECURE_BOOT_SIGN}" = "1" ]; then

        [ -f "${RPI_SECURE_BOOT_SIGN_KEY}" ] || bbfatal "Secure boot signing key not found: ${RPI_SECURE_BOOT_SIGN_KEY}"
        # Sign boot.img
        rpi-eeprom-digest -k ${RPI_SECURE_BOOT_SIGN_KEY} \
                          -i ${RPI_SECURE_BOOTIMG} \
                          -o ${RPI_SECURE_BOOTIMG_SIG} \
                         || bbfatal "Failed to generate signature for ${RPI_SECURE_BOOTIMG}"

        # Generate signed EEPROM firmware with config and digest for secure boot
        [ -f "${RPI_SECURE_BOOT_EEPROM}" ] || bbfatal "EEPROM firmware not found: ${RPI_SECURE_BOOT_EEPROM}"
        rpi-eeprom-digest -k ${RPI_SECURE_BOOT_SIGN_KEY} \
                          -i ${RPI_SECURE_BOOT_CONFIG} \
                          -o ${RPI_SECURE_BOOT_CONFIG_SIG} \
                         || bbfatal "Failed to generate EEPROM digest for ${RPI_SECURE_BOOT_CONFIG}"

        # Generate signed EEPROM firmware with config and digest for secure boot
        SIGN_PUBKEY="${WORKDIR}/secure-boot-pubkey.pem"
        openssl rsa -in "${RPI_SECURE_BOOT_SIGN_KEY}" -pubout -out "${SIGN_PUBKEY}"
        rpi-eeprom-config --pubkey ${SIGN_PUBKEY} \
                          --config ${RPI_SECURE_BOOT_CONFIG} \
                          --digest ${RPI_SECURE_BOOT_CONFIG_SIG} \
                          --out    ${RPI_SECURE_BOOT_EEPROM_SIGNED} \
                                   ${RPI_SECURE_BOOT_EEPROM} \
                        || bbfatal "Failed to generate signed EEPROM firmware ${RPI_SECURE_BOOT_EEPROM_SIGNED}"

        # Generate detached signature for the signed EEPROM binary
        rpi-eeprom-digest -k ${RPI_SECURE_BOOT_SIGN_KEY} \
                          -i ${RPI_SECURE_BOOT_EEPROM} \
                          -o ${RPI_SECURE_BOOT_EEPROM_SIG} \
                        || bbfatal "Failed to generate signature for ${RPI_SECURE_BOOT_EEPROM}"
    fi
}
