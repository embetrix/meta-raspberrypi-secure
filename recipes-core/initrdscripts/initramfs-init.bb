SUMMARY = "basic initramfs image init script"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = "file://initramfs-init.sh"

RDEPENDS:${PN}:append = " \
                busybox \
                util-linux-mount \
                util-linux-blkid \
                e2fsprogs-mke2fs \
                e2fsprogs-e2fsck \
                e2fsprogs-resize2fs \
                cryptsetup \
                raspi-utils-rpifwcrypto \
                raspi-utils-rpieepromab \
                block-device-id \
                keyutils \
                attr \
                ima-evm-utils \
                ima-policy-appraise-sb \
                ima-evm-keys \
                "

S = "${WORKDIR}"

do_install() {
    install -m 0755 ${WORKDIR}/initramfs-init.sh ${D}/init
    install -d ${D}/dev
    mknod -m 622 ${D}/dev/console c 5 1
}

FILES:${PN} += "/dev /init"
