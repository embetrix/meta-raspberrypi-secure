FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# add mount points for boot (update/active) data/backups partitions
dirs755 += " /boot-update \
             /boot-active \
             ${localstatedir}/data     \
             ${localstatedir}/backups  \
            "

# meta-integrity's base-files-ima.inc appends a second securityfs line
# with weak options; our fstab already has a hardened one, so remove it.
do_install:append() {
	sed -i '/^securityfs.*defaults/d' "${D}${sysconfdir}/fstab"
}
