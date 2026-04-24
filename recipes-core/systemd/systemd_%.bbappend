# Remove features irrelevant for embedded
PACKAGECONFIG:remove = " \
    hibernate \
    machined \
    nss-mymachines \
    quotacheck \
    utmp \
    "

PACKAGECONFIG:append = " journal-upload"

RRECOMMENDS:${PN} += "${PN}-journal-upload ${PN}-container"

do_install:append() {

    if [ "${RPI_SECURITY_PROFILE}" = "prod" ]; then
        # Harden systemd defaults to disable coredumps
        sed -i '/#DumpCore=/c\\DumpCore=no'                ${D}${sysconfdir}/systemd/system.conf
        sed -i '/#DefaultLimitCORE=/c\\DefaultLimitCORE=0' ${D}${sysconfdir}/systemd/system.conf
    fi

    # Enable hardware watchdog and reboot if systemd hangs for 15s
    sed -i '/#RuntimeWatchdogSec=/c\\RuntimeWatchdogSec=15'  ${D}${sysconfdir}/systemd/system.conf
    sed -i '/#RebootWatchdogSec=/c\\RebootWatchdogSec=10min' ${D}${sysconfdir}/systemd/system.conf

    # Limit journald size
    sed -i '/#Storage=/c\\Storage=persistent'              ${D}${sysconfdir}/systemd/journald.conf
    sed -i '/#SystemMaxUse=/c\\SystemMaxUse=256M'          ${D}${sysconfdir}/systemd/journald.conf
    sed -i '/#SystemMaxFileSize=/c\\SystemMaxFileSize=32M' ${D}${sysconfdir}/systemd/journald.conf
    sed -i '/#RuntimeMaxUse=/c\\RuntimeMaxUse=64M'         ${D}${sysconfdir}/systemd/journald.conf
}
