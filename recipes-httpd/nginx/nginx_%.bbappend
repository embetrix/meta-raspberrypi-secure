FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \ 
               file://nginx-override.conf \
               file://default_server.site"

RDEPENDS:${PN} += "rpi-device-certs"

NGINX_USERNAME ?= "rpi"
# Use a pre-generated password hash with openssl:
# openssl passwd -apr1 123456
NGINX_HASHED_PASSWORD ?= "$apr1$HD03o7ue$eoWU8IGTC/DRPwSKf5Zf1."

do_install:append() {

    echo "${NGINX_USERNAME}:"'${NGINX_HASHED_PASSWORD}' > ${D}${sysconfdir}/nginx/.htpasswd
    chmod 0644 ${D}${sysconfdir}/nginx/.htpasswd

    install -d ${D}${systemd_unitdir}/system/nginx.service.d
    install -m 0644 ${UNPACKDIR}/nginx-override.conf ${D}${systemd_unitdir}/system/nginx.service.d/
    install -m 0644 ${UNPACKDIR}/default_server.site ${D}${sysconfdir}/nginx/sites-available/default_server

}

FILES:${PN} += "${sysconfdir}/nginx/.htpasswd \
                ${systemd_unitdir}/system/nginx.service.d"
