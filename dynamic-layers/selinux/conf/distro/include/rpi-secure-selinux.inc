# Enable SELinux by default when meta-selinux is available.
# DISTRO_FEATURES:remove = "selinux" can disable it with the layer present.
DISTRO_FEATURES += "selinux"

# BBFILES_DYNAMIC discovers recipes and appends, but classes need BBPATH.
BBPATH .= ":${RPI_SECURE_BASE}/dynamic-layers/selinux"

PREFERRED_PROVIDER_virtual/refpolicy = "refpolicy-mls"
IMAGE_CLASSES += "${@bb.utils.contains('DISTRO_FEATURES', 'selinux', 'selinux-image selinux-image-order', '', d)}"
SELINUX_ENFORCING ?= "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'permissive', 'permissive', d)}"
#SELINUX_ENFORCING ?= "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'enforcing', 'permissive', d)}"
