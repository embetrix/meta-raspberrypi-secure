SUMMARY = "secure initramfs image init script"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://rpi-secure-initramfs-init.sh \
           file://init-common.sh \
           file://init-ab-slot.sh \
           file://init-crypto.sh \
           file://init-integrity.sh \
        "

RDEPENDS:${PN}:append = " \
                busybox \
                util-linux-mount \
                util-linux-blkid \
                util-linux-blockdev \
                e2fsprogs-mke2fs \
                e2fsprogs-e2fsck \
                dosfstools \
                libdevmapper \
                libubootenv-bin \
                raspi-utils-rpifwcrypto \
                keyutils \
                ima-evm-keys \
                avb-utils \
                "

S = "${UNPACKDIR}"

do_install() {
    install -m 0755 ${UNPACKDIR}/rpi-secure-initramfs-init.sh ${D}/init
    sed -i 's|__ROOTFS_TYPE___|${ROOTFS_TYPE}|g' ${D}/init
    install -d ${D}${libexecdir}/rpi-secure
    install -m 0644 ${UNPACKDIR}/init-common.sh ${D}${libexecdir}/rpi-secure/init-common.sh
    install -m 0644 ${UNPACKDIR}/init-ab-slot.sh ${D}${libexecdir}/rpi-secure/init-ab-slot.sh
    install -m 0644 ${UNPACKDIR}/init-crypto.sh ${D}${libexecdir}/rpi-secure/init-crypto.sh
    install -m 0644 ${UNPACKDIR}/init-integrity.sh ${D}${libexecdir}/rpi-secure/init-integrity.sh
    install -d ${D}/dev
    mknod -m 622 ${D}/dev/console c 5 1
}

FILES:${PN} += "/dev /init ${libexecdir}/rpi-secure"
