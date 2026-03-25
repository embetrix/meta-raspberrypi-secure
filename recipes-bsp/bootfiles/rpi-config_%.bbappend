FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://autoboot.txt"

ENABLE_WATCHDOG ??= ""
ENABLE_USB_MAX_CURRENT ??= ""
ENABLE_TRYBOOT_AB ??= ""
LOCK_DEVICE_KEY ??= ""

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

    if [ "${LOCK_DEVICE_KEY}" = "1" ]; then
        echo "# Lock device private key in OTP" >>$CONFIG
        echo "lock_device_private_key=1" >>$CONFIG
    fi
}
