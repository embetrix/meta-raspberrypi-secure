# Explicitly disable OverlayFS and default to bind mounts
AVOID_OVERLAYFS = "1"

# Additional volatile binds on encrypted R+W data partition:
# persist /var/log on the encrypted data partition
# bind mount wpa_supplicant config if wifi is enabled
# bind mount /root only in dev profile
VOLATILE_BINDS:append = "\
${localstatedir}/data${sysconfdir}/certs            ${sysconfdir}/certs\n\
${localstatedir}/data${sysconfdir}/ssh/keys         ${sysconfdir}/ssh/keys\n\
${localstatedir}/data${sysconfdir}/systemd/network/ ${sysconfdir}/systemd/network/\n\
${localstatedir}/data${sysconfdir}/systemd/journal-upload.conf ${sysconfdir}/systemd/journal-upload.conf\n\
${localstatedir}/data${localstatedir}/log ${localstatedir}/log\n\
${@bb.utils.contains('MACHINE_FEATURES', 'wifi', '${localstatedir}/data${sysconfdir}/wpa_supplicant ${sysconfdir}/wpa_supplicant\\n', '', d)}\
${@bb.utils.contains('RPI_SECURITY_PROFILE', 'dev', '${localstatedir}/data${ROOT_HOME} ${ROOT_HOME}\\n', '', d)}"
