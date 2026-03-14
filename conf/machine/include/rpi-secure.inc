# Extra packages
MACHINE_EXTRA_RDEPENDS += "usbguard"

# Silence firmware boot stage
ENABLE_UART = "0"
DISABLE_SPLASH = "1"
RPI_EXTRA_CONFIG = "init_uart_baud=0\n"

# Suppress kernel messages on console and remove any serial console= from cmdline
SERIAL_CONSOLES = ""
CMDLINE:append = " console=null quiet loglevel=0 ro"

# Device tree hardening
# Keep only the DTB and overlays required by the actual hardware
# to reduce kernel attack surface
# RPI_KERNEL_DEVICETREE_OVERLAYS = ""
# RPI_KERNEL_DEVICETREE = ""
