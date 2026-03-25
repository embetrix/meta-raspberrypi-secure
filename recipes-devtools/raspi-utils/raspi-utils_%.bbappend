FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRCREV = "b4074df7b79010c747ac4c4b00eca5819fcdf9d4"

# Add rpifwcrypto tool for OTP key management
DEPENDS += "gnutls"
OECMAKE_TARGET_COMPILE += "rpifwcrypto/all"
OECMAKE_TARGET_INSTALL += "rpifwcrypto/install"

# Add rpieepromab tool for A/B EEPROM management
OECMAKE_TARGET_COMPILE += "rpieepromab/all"
OECMAKE_TARGET_INSTALL += "rpieepromab/install"

PACKAGES =+ "${PN}-rpifwcrypto"
FILES:${PN}-rpifwcrypto = "${bindir}/rpi-fw-crypto"

PACKAGES =+ "${PN}-rpieepromab"
FILES:${PN}-rpieepromab = "${bindir}/rpi-eeprom-ab"
