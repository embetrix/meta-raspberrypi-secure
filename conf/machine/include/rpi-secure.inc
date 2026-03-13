# Extra packages
MACHINE_EXTRA_RDEPENDS += "usbguard"

# Device tree hardening
# Keep only the DTB and overlays required by the actual hardware
# to reduce kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
