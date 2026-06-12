PACKAGECONFIG:append = " journal-upload"
PACKAGECONFIG:remove = "osc-context"

RRECOMMENDS:${PN} += "${PN}-journal-upload ${PN}-container"

# Ship systemd-journal-upload but leave it disabled 
# enable explicitly when a log server is configured 
# in journal-upload.conf
SYSTEMD_AUTO_ENABLE:${PN}-journal-upload = "disable"

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
