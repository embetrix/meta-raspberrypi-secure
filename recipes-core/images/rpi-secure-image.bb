
DESCRIPTION = "rpi secure image"

inherit core-image

EXTRA_IMAGE_FEATURES:remove = " debug-tweaks"
IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

IMAGE_INSTALL:append = " \
   usbguard \
   iptables \
   "
