SUMMARY = "AVB public verification key"
DESCRIPTION = "Extracts and installs the AVB public key from AVB_SIGN_KEY \
for runtime verification by avb-verify / libavb"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

inherit python3native

DEPENDS = "avbtool-native"

do_install() {

    if [ -z "${AVB_SIGN_KEY}" ] || [ ! -f "${AVB_SIGN_KEY}" ]; then
        bbfatal "AVB_SIGN_KEY not found: ${AVB_SIGN_KEY}"
    fi
    avbtool extract_public_key --key "${AVB_SIGN_KEY}" --output ${WORKDIR}/avb_pubkey.bin
    install -d ${D}${sysconfdir}/avb
    install -m 0644 ${WORKDIR}/avb_pubkey.bin ${D}${sysconfdir}/avb/
}

do_install[vardeps] += "AVB_SIGN_KEY"
