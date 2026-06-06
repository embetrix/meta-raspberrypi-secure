FILESEXTRAPATHS:append := "${THISDIR}/files:"

SRC_URI:append = " \
     file://swupdate.cfg \
     file://swupdate-www.pwd \
     file://background.jpg \
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
    if [ -z "${SWUPDATE_SIGNING}" ] && [ -f "${SWUPDATE_CMS_CERT}" ]; then
        install -d ${D}${sysconfdir}/swupdate/crts
        install -m 644 "${SWUPDATE_CMS_CERT}" ${D}${sysconfdir}/swupdate/crts/
        sed -i '/public-key-file/c\\t\public-key-file = "${sysconfdir}/swupdate/crts/'$(basename ${SWUPDATE_CMS_CERT})'";' ${D}${sysconfdir}/swupdate/swupdate.cfg
    fi

    install -m 755 ${UNPACKDIR}/background.jpg   ${D}/www/images/background.jpg
    install -m 644 ${UNPACKDIR}/swupdate-www.pwd ${D}/www/swupdate-www.pwd
}

FILES:${PN} += "${sysconfdir}/swupdate"
