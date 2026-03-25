# Minimal cryptsetup for initramfs
PACKAGECONFIG = " \
    keyring \
    cryptsetup \
    luks2-reencryption \
    integritysetup \
    kernel_crypto \
    internal-argon2 \
    blkid \
    luks-adjust-xts-keysize \
    openssl \
"

# no need for kernel module RRECOMMENDS
RRECOMMENDS:${PN}:class-target = ""
