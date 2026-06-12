FILESEXTRAPATHS:append := "${THISDIR}/files:"

SRC_URI:append = " \
     file://0001-tools-optional-reboot-into-RPi-tryboot-mode.patch \
     file://0002-channel_curl-fix-wrong-evaluation-for-pkcs11-sslcert.patch \
     file://0003-channel_curl-support-OpenSSL-provider-for-PKCS-11-UR.patch \
     file://swupdate.cfg \
     file://background.jpg \
     file://index.html \
     file://swupdate.min.css \
     "

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN}  = "-g 4001 swupdate-www; -g 4002 swupdate-backend"
USERADD_PARAM:${PN}   = "-g 4001 -u 4001  --system --no-create-home -s /bin/false swupdate-www;  \
			             -g 4002 -u 4002  --system --no-create-home -s /bin/false swupdate-backend;"

do_install:append() {

    install -d ${D}${sysconfdir}/swupdate
    install -m 644 ${UNPACKDIR}/swupdate.cfg ${D}${sysconfdir}/swupdate/swupdate.cfg

    # Certificates are added if configured with artifacts signing
    if [ "${SWUPDATE_SIGNING}" = "CMS" ] && [ -f "${SWUPDATE_CMS_CERT}" ]; then
        install -d ${D}${sysconfdir}/swupdate/
        install -m 644 "${SWUPDATE_CMS_CERT}" ${D}${sysconfdir}/swupdate/
        sed -i 's|.*public-key-file.*|\tpublic-key-file = "${sysconfdir}/swupdate/'$(basename ${SWUPDATE_CMS_CERT})'";|' ${D}${sysconfdir}/swupdate/swupdate.cfg
    fi

    if [ -f "${SWUPDATE_AES_FILE}" ]; then
        install -d ${D}${sysconfdir}/swupdate/
        aes_keyfile="$(basename ${SWUPDATE_AES_FILE})"
        # Reformat openssl key/iv into the single-line "<key> <iv>" swupdate expects
        echo -n "$(grep key ${SWUPDATE_AES_FILE} | cut -d '=' -f 2) $(grep iv ${SWUPDATE_AES_FILE} | cut -d '=' -f 2)" \
            > ${UNPACKDIR}/${aes_keyfile}
        # ideally we should retriever encryption key from secure storage
        # provisioned at production on TPM or sealed using rpifwcrypto
        # then extracted and set at runtime using : swupdate-ipc aes
        install -m 0400 ${UNPACKDIR}/${aes_keyfile} ${D}${sysconfdir}/swupdate/${aes_keyfile}
        sed -i 's|.*aes-key-file.*|\taes-key-file = "${sysconfdir}/swupdate/'${aes_keyfile}'";|' ${D}${sysconfdir}/swupdate/swupdate.cfg
    fi
    
    # Polished swupdate web-UI
    install -m 755 ${UNPACKDIR}/index.html         ${D}/www/index.html
    install -m 644 ${UNPACKDIR}/swupdate.min.css   ${D}/www/css/swupdate.min.css
}

FILES:${PN} += "${sysconfdir}/swupdate"

RDEPENDS:${PN} += "raspi-utils"
RDEPENDS:${PN}-www += "nginx"
