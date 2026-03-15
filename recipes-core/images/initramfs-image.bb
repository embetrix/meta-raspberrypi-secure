DESCRIPTION = "Small image capable of booting a device. The kernel includes \
the Minimal RAM-based Initial Root Filesystem (initramfs), which finds the \
first 'init' program more efficiently."
LICENSE = "MIT"
PACKAGE_INSTALL = "initramfs-init base-files base-passwd ${VIRTUAL-RUNTIME_base-utils} ${ROOTFS_BOOTSTRAP_INSTALL}"

inherit core-image

# Do not pollute the initrd image with rootfs features
IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""

# initramfs is bundled inside the signed kernel image so skip IMA/EVM signing
ima_evm_sign_rootfs () {
    bbnote "IMA/EVM: Skipping signing for initramfs!"
}

IMAGE_FSTYPES = "${INITRAMFS_FSTYPES}"

IMAGE_ROOTFS_SIZE = "8192"
IMAGE_ROOTFS_EXTRA_SPACE = "0"
