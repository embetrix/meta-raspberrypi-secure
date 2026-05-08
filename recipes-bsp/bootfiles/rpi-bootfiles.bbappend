# rpi-fw-crypto is implemented in start4.elf on Pi4
# need a new version : https://github.com/raspberrypi/utils/issues/170
RPIFW_DATE = "20260408"
SRCREV = "dce3a7f35498e1a6340748f599e7d74d9001c1fe"
SRC_URI[sha256sum] = "f741c3c00a9aea6c211d52032b153fcf63e3b49829e0c2067fad67b93d4975cd"

# Overlay custom start4.elf/fixup4.dat for Pi4 to get USB working when Secure Boot is enabled
# see: https://github.com/raspberrypi/firmware/issues/2026
RPIFW2026_URI = "https://github.com/user-attachments/files/27532193/raspberrypi-firmware-2026.tar.gz;name=rpifw2026"
SRC_URI:append:raspberrypi4-64 = " ${RPIFW2026_URI}"
SRC_URI[rpifw2026.sha256sum] = "ebd4aa9f8b80da3ee00ea31674145db6b131ddb744232e83219fec317308b8d0"

do_deploy:append:raspberrypi4-64() {
    install -m 0644 ${WORKDIR}/raspberrypi-firmware-2026/start4.elf  ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/start4.elf
    install -m 0644 ${WORKDIR}/raspberrypi-firmware-2026/fixup4.dat  ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/fixup4.dat
}
