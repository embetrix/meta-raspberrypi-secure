SRC_URI = " \
    git://github.com/raspberrypi/rpi-eeprom.git;protocol=https;branch=ab \
"

# Update to latest rpi-eeprom firmware and add support for A/B boot and firmware crypto
SRCREV = "0d9e0930152393750a8de357c4aa17d4b3380e19"
PV = "v2026.03.02-2712"

# Add missing rdepends for findmnt used by the rpi-eeprom-update to determine the boot partition
RDEPENDS:${PN} += "util-linux-findmnt"
