FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \ 
               file://nginx-override.conf \
               file://default_server.site"

DEPENDS += "openssl-native"

RDEPENDS:${PN} += "rpi-device-certs"

NGINX_USERNAME ?= "rpi"
NGINX_PASSWORD ?= "123456"

do_install:append() {

    install -m 0644 ${D}${sysconfdir}/nginx/.htpasswd
    echo  "${NGINX_USERNAME}:$(openssl passwd -apr1 ${NGINX_PASSWORD})" > ${D}${sysconfdir}/nginx/.htpasswd

    install -d ${D}${systemd_unitdir}/system/nginx.service.d
    install -m 0644 ${UNPACKDIR}/nginx-override.conf ${D}${systemd_unitdir}/system/nginx.service.d/
    install -m 0644 ${UNPACKDIR}/default_server.site ${D}${sysconfdir}/nginx/sites-available/default_server

}

FILES:${PN} += "${sysconfdir}/nginx/.htpasswd \
                ${systemd_unitdir}/system/nginx.service.d"
