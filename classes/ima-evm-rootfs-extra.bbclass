# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Preserve /etc/fstab xattrs across ima_evm_sign_rootfs.
#
# meta-security's ima_evm_sign_rootfs runs `perl -pi -e` on /etc/fstab to add
# the iversion mount option. `perl -i` writes a tempfile and renames over the
# original, producing a new inode with no xattrs. That drops the
# security.selinux label set by selinux_set_labels, so /etc/fstab ends up as
# unlabeled_t on the running system and the EVM signature covers the wrong
# context.
#
# Workaround: rename /etc/fstab out of the way before ima_evm_sign_rootfs so
# the upstream `if [ -f etc/fstab ]` guard is false and perl never runs. A
# rename within the same filesystem keeps the same inode and xattrs, so the
# label survives. evmctl signs the file under the temporary name; EVM/IMA
# signatures don't include the path, so renaming back leaves them valid.
#
# In this project iversion is applied to the writable ext4 partitions in the
# initramfs (see rpi-secure-initramfs-init.sh), so the upstream fstab patch
# is unnecessary as well as destructive.

ima_evm_sign_rootfs:prepend() {

    if [ -f ${IMAGE_ROOTFS}/etc/fstab ]; then
        mv ${IMAGE_ROOTFS}/etc/fstab ${IMAGE_ROOTFS}/etc/.fstab.orig
    fi
}

ima_evm_sign_rootfs:append() {

    if [ -f ${IMAGE_ROOTFS}/etc/.fstab.orig ]; then
        mv ${IMAGE_ROOTFS}/etc/.fstab.orig ${IMAGE_ROOTFS}/etc/fstab
    fi

}

