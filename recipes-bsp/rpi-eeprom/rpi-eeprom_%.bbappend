# Update to latest rpi-eeprom firmware that supports firmware crypto
SRCREV = "a34ba1bcc4f46a2f4c7f3b1e806a238fdacd3698"
PV = "v2026.02.23-git${SRCPV}"

# Add missing rdepends for findmnt used by the rpi-eeprom-update to determine the boot partition
RDEPENDS:${PN} += "util-linux-findmnt"

# Enable native class
COMPATIBLE_MACHINE:class-native = ".*"

DEPENDS:append:class-native = " python3-native \
                                python3-pycryptodomex-native \
                                openssl-native \
                                xxd-native"

RDEPENDS:${PN}:class-native = ""

do_install:class-native() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/rpi-eeprom-config ${D}${bindir}
    install -m 0755 ${S}/rpi-eeprom-digest ${D}${bindir}
}

# SoC family for EEPROM firmware selection per machine
RPI_EEPROM_SOC:raspberrypi5 = "2712"
RPI_EEPROM_SOC:raspberrypi4 = "2711"
VARIANT="latest"

inherit deploy

# Ignore native
do_deploy:class-native() {
    :
}

# Deploy the latest EEPROM firmware binaries for secure boot signing
do_deploy() {

    install -d "${DEPLOYDIR}"
    LATEST_FW=$(ls ${S}/firmware-${RPI_EEPROM_SOC}/${VARIANT}/pieeprom-*.bin 2>/dev/null | sort | tail -1)
    install -m 0644 "$LATEST_FW" "${DEPLOYDIR}/pieeprom.bin"
    install -m 0644 "${S}/firmware-${RPI_EEPROM_SOC}/${VARIANT}/recovery.bin" "${DEPLOYDIR}/recovery.bin"
}

addtask deploy before do_build after do_install

BBCLASSEXTEND = "native"
