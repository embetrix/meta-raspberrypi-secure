FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRCREV = "1236508f013ca82115a5907ebb942e75ab94d8af"

# Add rpifwcrypto tool for firmware encryption / OTP key management
DEPENDS += "gnutls"
OECMAKE_TARGET_COMPILE += "rpifwcrypto/all"
OECMAKE_TARGET_INSTALL += "rpifwcrypto/install"
