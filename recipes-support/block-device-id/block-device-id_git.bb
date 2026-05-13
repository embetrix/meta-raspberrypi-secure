SUMMARY = "Retrieve hardware-innate unique identifiers from block devices"
HOMEPAGE = "https://github.com/raspberrypi/block-device-id"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=6aed68022a29ddf0c4aa97888031223f"

SRC_URI = "git://github.com/raspberrypi/block-device-id.git;protocol=https;branch=main"
SRCREV = "f14ce68c72560d97827dcb18e0544f00df002169"

inherit cargo cargo-update-recipe-crates

CARGO_BUILD_FLAGS:remove = " --frozen"
CARGO_BUILD_FLAGS:append = " --offline"

require ${BPN}-crates.inc
