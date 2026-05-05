#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Generate device certificates
# Usage: device-certs.sh [--force]
#   --force: regenerate all device certificates even if they already exist


if [ "$1" = "--force" ]; then
    echo "Force mode: regenerating all device certificates"
    rm -f *.pem
fi

# Get device IPv4 address
DEVICE_IP=$(networkctl status | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '^127\.' | head -1)
if ! echo "$DEVICE_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "Invalid device IP: $DEVICE_IP"
    exit 1
fi

HOSTNAME=$(hostname)

# Generate a self-signed device certificate whose private key lives in the
# RPi OTP-backed PKCS#11 token (no key material ever stored on disk).
# Override the token name / key id with PKCS11_TOKEN / SERVER_KEY_ID.
PKCS11_TOKEN="${PKCS11_TOKEN:-RPi%20OTP%20key}"
SERVER_KEY_ID="${SERVER_KEY_ID:-%01}"
SERVER_KEY_URI="pkcs11:object=${PKCS11_TOKEN};id=${SERVER_KEY_ID};type=private"

if [ ! -f device-cert.pem ]; then
    openssl req -x509 -new -provider pkcs11 -provider default \
            -key "$SERVER_KEY_URI" \
            -out device-cert.pem -days 365 \
            -subj "/C=DE/ST=BW/O=Embetrix/OU=DeviceCert/CN=$HOSTNAME" \
            -addext "subjectAltName=DNS:$HOSTNAME,DNS:localhost,IP:$DEVICE_IP,IP:127.0.0.1" \
            -addext "keyUsage=digitalSignature" \
            -addext "extendedKeyUsage=serverAuth" || exit 1
fi

chmod 644 *.pem
