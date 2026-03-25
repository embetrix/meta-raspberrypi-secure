FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://autoboot.txt"

ENABLE_WATCHDOG ??= ""
ENABLE_USB_MAX_CURRENT ??= ""
ENABLE_TRYBOOT_AB ??= ""
LOCK_DEVICE_KEY ??= ""
ENABLE_TPM_SLB9670  ??= ""
ENABLE_TPM_STM  ??= ""

do_deploy:append() {

    install -m 0644 ${WORKDIR}/autoboot.txt ${DEPLOYDIR}/autoboot.txt

    if [ "${ENABLE_WATCHDOG}" = "1" ]; then
        echo "# Enable watchdog"   >>$CONFIG
        echo "dtparam=watchdog=on" >>$CONFIG
    fi

    if [ "${ENABLE_USB_MAX_CURRENT}" = "1" ]; then
        echo "# Enable USB max current" >>$CONFIG
        echo "usb_max_current_enable=1" >>$CONFIG
    fi

    if [ "${ENABLE_TRYBOOT_AB}" = "1" ]; then
        echo "# Enable A/B boot" >>$CONFIG
        echo "tryboot_a_b=1"     >>$CONFIG
    fi

    if [ "${ENABLE_TPM_SLB9670}" = "1" ]; then
        echo "# Enable TPM SLB9670 support" >>$CONFIG
        echo "dtparam=spi=on" >>$CONFIG
        echo "dtoverlay=tpm-slb9670" >>$CONFIG
    fi

    if [ "${ENABLE_TPM_STM}" = "1" ]; then
        echo "# Enable TPM STM support" >>$CONFIG
        echo "dtparam=spi=on" >>$CONFIG
        echo "dtoverlay=tpm-stm" >>$CONFIG
    fi

    if [ "${LOCK_DEVICE_KEY}" = "1" ]; then
        echo "# Lock device private key in OTP" >>$CONFIG
        echo "lock_device_private_key=1" >>$CONFIG
    fi
}
