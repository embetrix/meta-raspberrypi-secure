PACKAGECONFIG:remove = " \
    hibernate \
    machined \
    nss-mymachines \
    quotacheck \
    sysvinit \
    utmp \
"

PACKAGECONFIG:append = " cryptsetup cryptsetup-plugins"

RRECOMMENDS:${PN} += "systemd-crypt systemd-container"

do_install:append() {

     # Harden systemd defaults to disable coredumps
     sed -i '/#DumpCore=/c\\DumpCore=no'                ${D}${sysconfdir}/systemd/system.conf
     sed -i '/#DefaultLimitCORE=/c\\DefaultLimitCORE=0' ${D}${sysconfdir}/systemd/system.conf
}
