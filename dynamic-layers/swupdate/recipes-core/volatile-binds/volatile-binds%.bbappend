# Persist per-device hawkBit settings on the encrypted data partition.
VOLATILE_BINDS:append = "\
${localstatedir}/data${sysconfdir}/swupdate/suricatta.conf ${sysconfdir}/swupdate/suricatta.conf\n\
"
