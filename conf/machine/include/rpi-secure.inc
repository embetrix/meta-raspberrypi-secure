# Extra packages
MACHINE_EXTRA_RDEPENDS += "usbguard"

# Disable serial console (no UART output from bootloader or kernel)
ENABLE_UART = "0"
SERIAL_CONSOLES = ""

# Device tree hardening
# Keep only the DTB and overlays required by the actual hardware
# to reduce kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
