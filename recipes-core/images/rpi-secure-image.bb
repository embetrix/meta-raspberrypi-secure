DESCRIPTION = "rpi secure image"

inherit core-image extrausers

IMAGE_FEATURES:append = " read-only-rootfs ssh-server-openssh"

# create a non admin user rpi
EXTRA_USERS_PARAMS = " \
	useradd -m -s /bin/sh rpi; \
	usermod -p '\$6\$9cqQEEUp8W2v9Hv2\$QvBII.wJgSVPJUMVU469rgFbHM5aC2n3psHfIYLKBEjstJlAKA2RynzJeYsNUa6V5czK7RyWOUj0lM8gH1oMM.' rpi; \
"

IMAGE_INSTALL:append = " \
	auditd   \      
	iptables \
	"
