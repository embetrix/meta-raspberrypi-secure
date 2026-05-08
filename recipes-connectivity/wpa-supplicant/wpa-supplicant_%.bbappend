FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://wpa_supplicant@.service \
            file://wpa_supplicant-wlan0.conf \
            file://80-wlan-interface.rules"

SYSTEMD_AUTO_ENABLE = "disable"

do_install:append () {

   install -m 644 ${WORKDIR}/wpa_supplicant@.service ${D}/${systemd_system_unitdir}
   install -d ${D}${sysconfdir}/wpa_supplicant/
   install -D -m 600 ${WORKDIR}/wpa_supplicant-wlan0.conf ${D}${sysconfdir}/wpa_supplicant/

   install -d ${D}${sysconfdir}/udev/rules.d
   install -m 0644 ${WORKDIR}/80-wlan-interface.rules ${D}${sysconfdir}/udev/rules.d
}

FILES_${PN} += "${sysconfdir}/udev/rules.d"
