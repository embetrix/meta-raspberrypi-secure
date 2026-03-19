SUMMARY = "IMA/EVM custom appraise policy"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = " file://ima_policy_appraise_sb"

inherit features_check
REQUIRED_DISTRO_FEATURES = "ima"

do_install () {
    install -d ${D}/${sysconfdir}/ima
    install ${WORKDIR}/ima_policy_appraise_sb ${D}/${sysconfdir}/ima/ima-policy
}

FILES:${PN} = "${sysconfdir}/ima"
RDEPENDS:${PN} = "ima-evm-utils"
