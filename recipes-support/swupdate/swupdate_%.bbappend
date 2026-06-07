FILESEXTRAPATHS:append := "${THISDIR}/files:"

SRC_URI:append = " \
     file://swupdate.cfg \
     file://background.jpg \
     file://swupdate-progress-tryboot.conf \
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

    # Override swupdate-progress reboot to use RPi tryboot
    install -d ${D}${systemd_system_unitdir}/swupdate-progress.service.d
    install -m 644 ${UNPACKDIR}/swupdate-progress-tryboot.conf \
        ${D}${systemd_system_unitdir}/swupdate-progress.service.d/tryboot.conf
}

FILES:${PN} += "${sysconfdir}/swupdate"
FILES:${PN}-progress += "${systemd_system_unitdir}/swupdate-progress.service.d"

RDEPENDS:${PN}-www += "rpi-device-certs"
