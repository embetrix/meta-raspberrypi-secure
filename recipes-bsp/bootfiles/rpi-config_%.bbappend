FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://autoboot.txt \
            file://bootconf.txt \
            file://bootconf-recovery.txt \
            file://readme.txt"

ENABLE_WATCHDOG ??= ""
ENABLE_USB_MAX_CURRENT ??= ""
ENABLE_PCIEX ??= ""
ENABLE_TRYBOOT_AB ??= ""
LOCK_DEVICE_KEY ??= ""
ENABLE_TPM_SLB9670  ??= ""
PROGRAM_PUBLIC_KEY ??= ""
PROGRAM_JTAG_LOCK ??= ""

do_deploy:append() {

    install -m 0644 ${WORKDIR}/autoboot.txt ${DEPLOYDIR}/autoboot.txt
    install -m 0644 ${WORKDIR}/bootconf.txt ${DEPLOYDIR}/bootconf.txt
    install -m 0644 ${WORKDIR}/bootconf-recovery.txt ${DEPLOYDIR}/bootconf-recovery.txt
    install -m 0644 ${WORKDIR}/readme.txt ${DEPLOYDIR}/readme.txt
    # Disable BOOT_UART in production profile
    if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
        sed -i 's/^BOOT_UART=.*/BOOT_UART=0/' ${DEPLOYDIR}/bootconf.txt
    fi

    if [ "${ENABLE_UART_2NDSTAGE}" = "1" ]; then
        echo "# Enable UART in 2nd stage" >>$CONFIG
        echo "uart_2ndstage=1" >>$CONFIG
    fi
    if [ "${ENABLE_WATCHDOG}" = "1" ]; then
        echo "# Enable watchdog"   >>$CONFIG
        # dtparam=watchdog is only recognized on RPi4 (BCM2711)
        # On RPi5 (BCM2712) is enabled by default
        case "${MACHINE}" in
            raspberrypi4*) echo "dtparam=watchdog=on" >>$CONFIG ;;
        esac
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
        echo "dtoverlay=tpm-slb9670" >>$CONFIG
    fi

    if [ "${ENABLE_PCIEX}" = "1" ]; then
        echo "# Enable PCIe support" >>$CONFIG
        case "${MACHINE}" in
            raspberrypi5*) echo "dtparam=pciex1_gen=3" >>$CONFIG ;;
        esac
    fi

    if [ "${LOCK_DEVICE_KEY}" = "1" ]; then
        echo "# Lock device private key in OTP" >>$CONFIG
        echo "lock_device_private_key=1" >>$CONFIG
    fi

    if [ "${PROGRAM_PUBLIC_KEY}" = "1" ]; then
        echo "# Program public key in OTP" >>$CONFIG
        echo "program_public_key=1" >>$CONFIG
    fi

    if [ "${PROGRAM_JTAG_LOCK}" = "1" ]; then
        echo "# Program JTAG lock in OTP" >>$CONFIG
        echo "program_jtag_lock=1" >>$CONFIG
    fi
}
