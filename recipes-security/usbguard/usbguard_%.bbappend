FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://rules.d/10-root-hubs.conf \
            file://rules.d/20-mass-storage.conf \
            file://rules.d/30-smartcard.conf \
            file://rules.d/99-reject.conf \
            file://usbguard-daemon.conf \
            "
# Drop OpenSSL in favor of libsodium for better Selinux policy compatibility
PACKAGECONFIG:remove = " openssl"
PACKAGECONFIG:append = " libsodium"

DEPENDS += "audit"
RDEPENDS:${PN} += "auditd"

EXTRA_OECONF += "--enable-audit"

do_install:append() {
    install -d ${D}${sysconfdir}/usbguard
    install -m 0600 ${UNPACKDIR}/usbguard-daemon.conf ${D}${sysconfdir}/usbguard/

    rm -f ${D}${sysconfdir}/usbguard/rules.conf
    install -d ${D}${sysconfdir}/usbguard/rules.d
    install -m 0600 ${UNPACKDIR}/rules.d/*.conf ${D}${sysconfdir}/usbguard/rules.d/
}
