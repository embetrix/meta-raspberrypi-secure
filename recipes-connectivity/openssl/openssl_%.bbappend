FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://openssl-rpifwcrypto.cnf"

RRECOMMENDS:${PN}:class-target:rpi = "rpifwcrypto-pkcs11"

do_install:append:class-target:rpi () {

    install -m 0644 ${UNPACKDIR}/openssl-rpifwcrypto.cnf      ${D}${sysconfdir}/ssl/
    printf "\n# Enable rpifwcrypto provider config\n.include /etc/ssl/openssl-rpifwcrypto.cnf\n"  >> ${D}${sysconfdir}/ssl/openssl.cnf
}

FILES:openssl-conf:append:rpi = " ${sysconfdir}/ssl/openssl-rpifwcrypto.cnf"
