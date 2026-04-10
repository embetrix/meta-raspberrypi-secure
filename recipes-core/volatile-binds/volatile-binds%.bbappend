# Explicitly disable OverlayFS and default to bind mounts
AVOID_OVERLAYFS = "1"

# Additional volatile binds on encrypted R+W data partition
VOLATILE_BINDS += "\
                /var/data/etc/certs            /etc/certs\n\
                /var/data/etc/ssh/keys         /etc/ssh/keys\n\
                /var/data/etc/systemd/network/ /etc/systemd/network/\n\
                /var/data/etc/systemd/journal-upload.conf /etc/systemd/journal-upload.conf\n\
                /var/data/tailscale            /var/tailscale\n"

# Persist logs when volatile log directory is disabled
VOLATILE_BINDS:append = "${@'/var/data/var/log /var/log\\n' if d.getVar('VOLATILE_LOG_DIR') == 'no' else ''}"

# Bind mount wpa_supplicant config if wifi is enabled
VOLATILE_BINDS:append = "${@bb.utils.contains('MACHINE_FEATURES', 'wifi', '/var/data/etc/wpa_supplicant /etc/wpa_supplicant\\n', '', d)}"

# Bind mount /home/root only in dev profile
VOLATILE_BINDS:append = "${@bb.utils.contains('RPI_SECURITY_PROFILE', 'dev', '/var/data/home/root /home/root\\n', '', d)}"
