# Explicitly skip OverlayFS and default to bind mounts
AVOID_OVERLAYFS = "1"

# Additional volatile binds on encrypted R+W data partition
VOLATILE_BINDS += "\
                /var/data/etc/certs /etc/certs\n\
                /var/data/home/root /home/root\n\
                /var/data/etc/systemd/network/ /etc/systemd/network/\n"
