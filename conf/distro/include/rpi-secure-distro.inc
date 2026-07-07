# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

DISTRO = "rpi-secure"
DISTRO_NAME = "rpi-secure"
INHERIT += "rpi-secure-version"
DISTRO_VERSION := "${RPI_SECURE_VERSION}"

# replace datetime in image version by predictable git tag derived version
IMAGE_VERSION_SUFFIX = "-${RPI_SECURITY_PROFILE}_${RPI_SECURE_VERSION}"

# Distro Features
DISTRO_FEATURES  += "systemd polkit ima integrity security selinux tpm2"

# Prefer nginx 1.29.x mainline for OpenSSL Provider support
PREFERRED_VERSION_nginx = "1.29%"

# Prefer avahi-libnss-mdns for mDNS support
PREFERRED_RPROVIDER_libnss-mdns = "avahi-libnss-mdns"

# Disable syslog as it is not needed as we use journald
VIRTUAL-RUNTIME_base-utils-syslog = ""

# Security profile "dev" or "prod"
RPI_SECURITY_PROFILE ?= "dev"

# Overwrite machine config
require conf/machine/${MACHINE}-secure.conf

# Set persistent Logs
FILESYSTEM_PERMS_TABLES:remove = "files/fs-perms-volatile-log.txt"

# Selinux configuration
PREFERRED_PROVIDER_virtual/refpolicy = "refpolicy-mls"
IMAGE_CLASSES += "selinux-image selinux-image-order"
SELINUX_ENFORCING ?= "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'permissive', 'permissive', d)}"
#SELINUX_ENFORCING ?= "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'enforcing', 'permissive', d)}"

# IMA/EVM Rootfs Signing
INHERIT += "ima-evm-rootfs"
IMAGE_CLASSES += "ima-evm-rootfs-extra"

# AVB/DM-Verity configuration
IMAGE_CLASSES += "avb-verity"
IMAGE_FSTYPES += " ${ROOTFS_TYPE}.avbverity.gz"
AVB_ROOT_HASH_SIGN ?= "1"

# SWUpdate configuration
SWUPDATE_SIGNING = "CMS"

# Include image build information
INHERIT += "image-buildinfo"

# Enable allow-root-login and remove all insecure features in prod
EXTRA_IMAGE_FEATURES += "allow-root-login"
EXTRA_IMAGE_FEATURES:remove = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'allow-empty-password empty-root-password allow-root-login', '', d)}"

# CVE checks conditional on security profile
IMAGE_CLASSES += "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'sbom-cve-check', '', d)}"
require conf/distro/include/cve-extra-exclusions.inc

# Enable SCA checks
INHERIT += "sca"
SCA_ENABLE = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', '1', '0', d)}"
#SCA_WARNING_LEVEL = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'prod', 'error', 'warning', d)}"
SCA_WARNING_LEVEL = "warning"
SCA_AUTO_INH_ON_IMAGE = "1"
SCA_AUTO_INH_ON_RECIPE = "0"
SCA_VERBOSE_OUTPUT = "0"
SCA_SCOPE_FILTER = "security"
SCA_ENABLED_MODULES_RECIPE = "cppcheck flawfinder bandit shellcheck detectsecrets kconfighard"
SCA_ENABLED_MODULES_IMAGE  = "shellcheck detectsecrets bandit"

# Licenses accepted for this distro configuration:
# Please check this legal notice:
# https://meta-raspberrypi.readthedocs.io/en/latest/ipcompliance.html
LICENSE_FLAGS_ACCEPTED += "synaptics-killswitch"
