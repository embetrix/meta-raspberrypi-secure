SUMMARY = "ThermoPro Bluetooth LE sensor reader"
DESCRIPTION = "Discover ThermoPro sensors through BlueZ and report readings as JSON, \
               with optional SQLite logging and ThingsBoard MQTT publishing."
HOMEPAGE = "https://github.com/embetrix/thermopro-sensor"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/embetrix/thermopro-sensor.git;protocol=https;branch=main \
           file://persistent-data.conf \
           file://thermopro-config.mount \
           file://thermopro-state.mount \
           file://thermopro-sensor.tmpfiles \
           file://openssl-thingsboard.cnf \
           file://tls.conf \
"
SRCREV = "3ddd76be5aa20cc956e259428ee829bd46b96953"
PV = "1.0+git"

inherit cmake pkgconfig systemd features_check useradd

REQUIRED_DISTRO_FEATURES = "bluetooth systemd"

DEPENDS = "json-c mosquitto sqlite3 systemd"
RDEPENDS:${PN} += "bluez5 ca-certificates openssl-conf"

# A stable account owns the database across service restarts
USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "--system thermopro-sensor"
USERADD_PARAM:${PN} = "--system --gid thermopro-sensor --no-create-home \
                      --home-dir ${localstatedir}/lib/thermopro-sensor \
                      --shell /sbin/nologin thermopro-sensor"

EXTRA_OECMAKE += " \
    -DBUILD_TESTING=OFF \
    -DSYSTEMD_UNIT_DIR=${systemd_system_unitdir} \
"

SYSTEMD_SERVICE:${PN} = "thermopro-sensor.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}/thermopro-sensor.service.d
    install -m 0644 ${UNPACKDIR}/persistent-data.conf \
        ${D}${systemd_system_unitdir}/thermopro-sensor.service.d/persistent-data.conf
    install -m 0644 ${UNPACKDIR}/tls.conf \
        ${D}${systemd_system_unitdir}/thermopro-sensor.service.d/tls.conf

    install -m 0644 ${UNPACKDIR}/thermopro-config.mount \
        '${D}${systemd_system_unitdir}/etc-thermopro\x2dsensor-thermopro\x2dsensor.json.mount'
    install -m 0644 ${UNPACKDIR}/thermopro-state.mount \
        '${D}${systemd_system_unitdir}/var-lib-thermopro\x2dsensor.mount'

    install -d ${D}${sysconfdir}/ssl
    install -m 0644 ${UNPACKDIR}/openssl-thingsboard.cnf ${D}${sysconfdir}/ssl/openssl-thingsboard.cnf

    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${UNPACKDIR}/thermopro-sensor.tmpfiles \
        ${D}${nonarch_libdir}/tmpfiles.d/thermopro-sensor.conf
}

FILES:${PN} += "${systemd_system_unitdir}/thermopro-sensor.service.d \
                ${systemd_system_unitdir}/*.mount \
                ${nonarch_libdir}/tmpfiles.d/thermopro-sensor.conf"

CONFFILES:${PN} += "${sysconfdir}/thermopro-sensor/thermopro-sensor.json \
                    ${sysconfdir}/ssl/openssl-thingsboard.cnf"
