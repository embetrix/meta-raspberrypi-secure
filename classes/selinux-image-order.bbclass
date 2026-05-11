# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Ensure SELinux labeling runs BEFORE IMA/EVM signing in IMAGE_PREPROCESS_COMMAND.
#
# Both selinux-image.bbclass and ima-evm-rootfs.bbclass append their hook via
# a RecipePreFinalise event handler. Handler registration order determines
# execution order, and in our config ima-evm-rootfs's handler registers first.
# That would sign xattrs before SELinux rewrites security.selinux and
# invalidate every EVM signature. Force the order here.

IMAGE_CLASSES += "selinux-image"

python selinux_image_order_handler() {
    cmd = d.getVar('IMAGE_PREPROCESS_COMMAND') or ''
    if 'selinux_set_labels;' not in cmd or 'ima_evm_sign_rootfs;' not in cmd:
        return
    cmd = cmd.replace('selinux_set_labels;', '').replace('ima_evm_sign_rootfs;', '')
    d.setVar('IMAGE_PREPROCESS_COMMAND',
             cmd.rstrip() + ' selinux_set_labels; ima_evm_sign_rootfs;')
}

addhandler selinux_image_order_handler
selinux_image_order_handler[eventmask] = "bb.event.RecipeTaskPreProcess"
