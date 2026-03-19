FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# add mount points for data/backups partitions
dirs755 += " ${localstatedir}/data     \
             ${localstatedir}/backups  \
            "
