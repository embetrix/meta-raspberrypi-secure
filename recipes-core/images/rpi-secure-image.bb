DESCRIPTION = "rpi secure image"

inherit core-image extrausers

IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

EXTRA_USERS_PARAMS = "useradd -m -s /bin/sh rpi;"
