# Enable the SLB9670 hardware integration by default when meta-tpm is present.
MACHINE_FEATURES += "tpm"
ENABLE_TPM_SLB9670 = "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', '1', '0', d)}"
MACHINE_EXTRA_RRECOMMENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'packagegroup-security-tpm2', '', d), '', d)}"
RPI_KERNEL_DEVICETREE_OVERLAYS += "${@bb.utils.contains('MACHINE_FEATURES', 'tpm', 'overlays/tpm-slb9670.dtbo', '', d)}"
