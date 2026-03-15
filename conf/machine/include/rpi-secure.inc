# Extra packages
MACHINE_EXTRA_RRECOMMENDS += "\
    usbguard \
    rpi-config \
    rpi-eeprom \
    raspi-utils \
    "

# Silence firmware boot stage
DISABLE_SPLASH = "1"
RPI_EXTRA_CONFIG = "init_uart_baud=0\ndtparam=watchdog=on\n"

# Suppress kernel messages on console and remove any serial console= from cmdline
SERIAL_CONSOLES = ""
CMDLINE:append = " console=null quiet loglevel=0 ro"

# ship kernel + initramfs in boot partition
IMAGE_BOOT_FILES += "${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin;${SDIMG_KERNELIMAGE}"

# Device tree hardening
# Keep only the DTB and overlays required by the actual hardware
# to reduce kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
