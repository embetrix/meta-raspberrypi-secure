FILESEXTRAPATHS:append := "${THISDIR}/files:"

SRC_URI:append = " \
     file://0001-tools-optional-reboot-into-RPi-tryboot-mode.patch \
     file://0002-channel_curl-fix-wrong-evaluation-for-pkcs11-sslcert.patch \
     file://0003-channel_curl-support-OpenSSL-provider-for-PKCS-11-UR.patch \
     file://0004-channel_curl-fix-HASH_final-return-value-check.patch \
     file://swupdate.cfg \
     file://suricatta.conf \
     file://20-suricatta-args \
     file://sw-versions \
     file://background.jpg \
     file://index.html \
     file://swupdate.min.css \
     file://ab-verify-slot \
     file://ab-verify-slot.service \
     file://ab-verify-slot.timer \
     "

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-g 4001 swupdate-www; -g 4002 swupdate-backend"
USERADD_PARAM:${PN}  = "-u 4001 -g 4001 --system --no-create-home -s /bin/false swupdate-www; \
                        -u 4002 -g 4002 --system --no-create-home -s /bin/false swupdate-backend"

do_install:append() {

    install -d ${D}${sysconfdir}/swupdate
    install -m 644 ${UNPACKDIR}/swupdate.cfg ${D}${sysconfdir}/swupdate/swupdate.cfg

    # Per-device suricatta (hawkBit) settings: device id (defaults to hostname)
    # and gateway token, provisionable at runtime without rebuilding the image.
    install -m 600 ${UNPACKDIR}/suricatta.conf ${D}${sysconfdir}/swupdate/suricatta.conf

    # conf.d snippet sourced by swupdate.sh to build the suricatta args
    install -d ${D}${libdir}/swupdate/conf.d
    install -m 644 ${UNPACKDIR}/20-suricatta-args ${D}${libdir}/swupdate/conf.d/20-suricatta-args

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

    # Add swupdate version file with RPI_SECURE_VERSION
    install -m 644 ${UNPACKDIR}/sw-versions   ${D}${sysconfdir}/sw-versions
    sed -i 's|__VERSION__|${RPI_SECURE_VERSION}|g' ${D}${sysconfdir}/sw-versions

    # Add hwrevision file with SOC_FAMILY and MACHINE
    echo "${SOC_FAMILY} ${MACHINE}" > ${D}${sysconfdir}/hwrevision
    chmod 644 ${D}${sysconfdir}/hwrevision

    # A/B update slot verification: script + service + timer
    install -d ${D}${sbindir}
    install -m 0755 ${UNPACKDIR}/ab-verify-slot ${D}${sbindir}/ab-verify-slot

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/ab-verify-slot.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/ab-verify-slot.timer   ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${sysconfdir}/swupdate \
                ${sysconfdir}/sw-versions \
                ${sysconfdir}/hwrevision"

CONFFILES:${PN} += "${sysconfdir}/swupdate/suricatta.conf"

# Verify a pending A/B update after boot (timer-triggered): 
# confirm the slot if healthy, rollback otherwise
SYSTEMD_SERVICE:${PN} += "ab-verify-slot.timer"
FILES:${PN} += "${systemd_system_unitdir}/ab-verify-slot.service"

RDEPENDS:${PN} += "raspi-utils libubootenv-bin rpi-ab-update swupdate-tools-ipc"
RDEPENDS:${PN}-www += "nginx"
