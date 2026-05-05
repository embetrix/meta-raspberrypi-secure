SUMMARY = "IMA/EVM secure boot appraise policy"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " file://ima_policy_appraise_sb"

inherit features_check
REQUIRED_DISTRO_FEATURES = "ima"

do_install () {
    install -d ${D}/${sysconfdir}/ima
    install ${WORKDIR}/ima_policy_appraise_sb ${D}/${sysconfdir}/ima/ima-policy
}

FILES:${PN} = "${sysconfdir}/ima"
RDEPENDS:${PN} = "ima-evm-utils"
