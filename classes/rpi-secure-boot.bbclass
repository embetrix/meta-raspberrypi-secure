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

do_image_rpi_secure_boot[depends] = " \
    mtools-native:do_populate_sysroot \
    dosfstools-native:do_populate_sysroot \
    virtual/kernel:do_deploy \
    rpi-bootfiles:do_deploy \
    ${@bb.utils.contains('RPI_SECURE_BOOT_SIGN', '1', 'openssl-native:do_populate_sysroot', '', d)} \
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

    rm -f ${WORKDIR}/boot.img
    mkfs.vfat -F32 -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img ${RPI_SECURE_BOOT_SPACE}
    mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${BOOTFILES_DIR_NAME}/* ::/ || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${BOOTFILES_DIR_NAME}/* into boot.img"
    if [ "${@bb.utils.contains("MACHINE_FEATURES", "armstub", "1", "0", d)}" = "1" ]; then
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/armstubs/${ARMSTUB} ::/ || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/armstubs/${ARMSTUB} into boot.img"
    fi
    if test -n "${DTS}"; then
        mmd -i ${WORKDIR}/boot.img overlays
        for entry in ${DTS} ; do
            if [ $(echo "$entry" | grep -c \;) = "0" ] ; then
                DEPLOY_FILE="$entry"
                DEST_FILENAME="$entry"
            else
                DEPLOY_FILE="$(echo "$entry" | cut -f1 -d\;)"
                DEST_FILENAME="$(echo "$entry" | cut -f2- -d\;)"
            fi
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${DEPLOY_FILE} ::${DEST_FILENAME} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${DEPLOY_FILE} into boot.img"
        done
    fi
    if [ "${RPI_USE_U_BOOT}" = "1" ]; then
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/u-boot.bin ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/u-boot.bin into boot.img"
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/boot.scr ::boot.scr || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/boot.scr into boot.img"
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin ::${KERNEL_IMAGETYPE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin into boot.img"
        else
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} ::${KERNEL_IMAGETYPE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} into boot.img"
        fi
    else
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin into boot.img"
        else
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} into boot.img"
        fi
    fi
    
    # Exclude files from boot.img if specified
    if [ -n "${SECURE_BOOT_FILES_EXCLUDE}" ]; then
        for entry in ${SECURE_BOOT_FILES_EXCLUDE} ; do
            mdel -i ${WORKDIR}/boot.img ::${entry} || bbfatal "mdel cannot remove ${entry} from boot.img"
        done
    fi

    cp ${WORKDIR}/boot.img ${RPI_SECURE_BOOTIMG}

    # Generate signature file for boot.img if secure boot enabled. 
    # The signature format is :
    # <sha256-hex>
    # ts: <unix-epoch-seconds>
    # rsa2048: <rsa-pkcs1v1.5-sha256-signature-hex>
    if [ "${RPI_SECURE_BOOT_SIGN}" = "1" ]; then
        SIGN_KEY="${RPI_SECURE_BOOT_SIGN_KEY}"

        if [ -f "${SIGN_KEY}" ]; then
            SIGN_TS="${RPI_SECURE_BOOT_SIGN_TIMESTAMP}"
            [ -z "$SIGN_TS" ] && SIGN_TS=$(date +%s)
            {
                openssl dgst -sha256 ${RPI_SECURE_BOOTIMG} | awk '{print $2}'
                echo "ts: $SIGN_TS"
                printf "rsa2048: "
                openssl dgst -sha256 -sign ${SIGN_KEY} ${RPI_SECURE_BOOTIMG} \
                | hexdump -v -e '1/1 "%02x"'; echo

            } > ${RPI_SECURE_BOOTIMG_SIG} || bbfatal "Failed to generate signature for ${RPI_SECURE_BOOTIMG}"
        else
            bbfatal "Secure boot signing key not found: ${SIGN_KEY}"
        fi
    fi
}
