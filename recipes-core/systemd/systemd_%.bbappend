# Remove features irrelevant for embedded
PACKAGECONFIG:remove = " \
    hibernate \
    machined \
    nss-mymachines \
    quotacheck \
    utmp \
"

PACKAGECONFIG:append = " cryptsetup cryptsetup-plugins journal-upload"

RRECOMMENDS:${PN} += "${PN}-journal-upload ${PN}-crypt ${PN}-container"

do_install:append() {

     # Harden systemd defaults to disable coredumps
     sed -i '/#DumpCore=/c\\DumpCore=no'                ${D}${sysconfdir}/systemd/system.conf
     sed -i '/#DefaultLimitCORE=/c\\DefaultLimitCORE=0' ${D}${sysconfdir}/systemd/system.conf

     # Enable hardware watchdog: reboot if systemd hangs for 15s
     sed -i '/#RuntimeWatchdogSec=/c\\RuntimeWatchdogSec=15' ${D}${sysconfdir}/systemd/system.conf
     sed -i '/#RebootWatchdogSec=/c\\RebootWatchdogSec=10min' ${D}${sysconfdir}/systemd/system.conf
}
