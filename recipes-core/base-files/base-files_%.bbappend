FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# add mount points for boot (inactive), blobs data partitions
dirs755 += " ${localstatedir}/boot-update \
             ${localstatedir}/data        \
            "

# meta-integrity's base-files-ima.inc appends a second securityfs line
# with weak options; our fstab already has a hardened one, so remove it.
do_install:append() {
	sed -i '/^securityfs.*defaults/d' "${D}${sysconfdir}/fstab"
}
