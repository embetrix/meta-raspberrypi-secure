
DESCRIPTION = "rpi secure image"

inherit core-image

EXTRA_IMAGE_FEATURES:remove = " debug-tweaks"
IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

IMAGE_CLASSES:append = " extrausers"

# extrausers/usermod -p expects crypt hashes, not plaintext.
# Generate with: openssl passwd -6 '<password>'
DISABLE_ROOT ?= "True"
ROOT_DEFAULT_PASSWORD_HASH ?= ""
DEFAULT_ADMIN_ACCOUNT ?= "myadmin"
DEFAULT_ADMIN_GROUP ?= "wheel"
DEFAULT_ADMIN_ACCOUNT_PASSWORD_HASH ?= "\$6\$S152C6yqXIAyYn4B\$vZ1FxKy7ZpR6VbCD2jFWFOOM2DYgX1PPavA.N8fDBuoTeny3zjhBxW2XyGvFG4YqvU8f02yA5wPCUa2izMivp1"

EXTRA_USERS_PARAMS = "${@bb.utils.contains('DISABLE_ROOT', 'True', 'usermod -L root;', 'usermod -p \'${ROOT_DEFAULT_PASSWORD_HASH}\' root;', d)}"

EXTRA_USERS_PARAMS:append = " useradd  ${DEFAULT_ADMIN_ACCOUNT};" 
EXTRA_USERS_PARAMS:append = " groupadd  ${DEFAULT_ADMIN_GROUP};" 
EXTRA_USERS_PARAMS:append = " usermod -p '${DEFAULT_ADMIN_ACCOUNT_PASSWORD_HASH}' ${DEFAULT_ADMIN_ACCOUNT};" 
EXTRA_USERS_PARAMS:append = " usermod -aG ${DEFAULT_ADMIN_GROUP}  ${DEFAULT_ADMIN_ACCOUNT};" 
EXTRA_USERS_PARAMS:append = " usermod -aG sudo ${DEFAULT_ADMIN_ACCOUNT};"


IMAGE_INSTALL:append = " \
   packagegroup-hardening \
   usbguard \
   iptables \
   "
