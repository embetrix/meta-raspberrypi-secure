#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Generate/renew Tailscale HTTPS certificates in /etc/certs/tailscale/
# Requires the device to be registered on a tailnet with HTTPS enabled

set -eu

CERT_DIR="/etc/certs/tailscale"

# Wait for tailscaled to be reachable
tailscale status >/dev/null 2>&1 || {
    echo "tailscale-certs: tailscaled not reachable — will retry"
    exit 0
}

# Check backend state device must be running (registered + connected)
state=$(tailscale status --json 2>/dev/null | sed -n 's/.*"BackendState": *"\([^"]*\)".*/\1/p')
case "$state" in
    Running) ;;
    NeedsLogin)
        echo "tailscale-certs: device not registered — run: tailscale up --auth-key=<key>"
        exit 0
        ;;
    *)
        echo "tailscale-certs: not ready (state: ${state:-unknown}) — will retry"
        exit 0
        ;;
esac

# Get device FQDN from tailscale dns name
# "tailscale dns name" is not available, use "tailscale whois" on own IP
self_ip=$(tailscale ip -4 2>/dev/null) || {
    echo "tailscale-certs: cannot get tailscale IP — will retry"
    exit 0
}

fqdn=$(tailscale whois "$self_ip" 2>/dev/null | sed -n 's/.*Name: *\([^ ]*\.ts\.net\).*/\1/p' | head -1)
fqdn="${fqdn%.}"

if [ -z "$fqdn" ]; then
    echo "tailscale-certs: cannot determine device FQDN"
    exit 1
fi

mkdir -p "$CERT_DIR"

echo "tailscale-certs: generating certificate for $fqdn"
tailscale cert \
    --cert-file "$CERT_DIR/$fqdn.crt" \
    --key-file  "$CERT_DIR/$fqdn.key" \
    "$fqdn"

chmod 0644 "$CERT_DIR/$fqdn.crt"
chmod 0640 "$CERT_DIR/$fqdn.key"

# Symlink predictable names for services that need them
ln -sf "$fqdn.crt" "$CERT_DIR/server.crt"
ln -sf "$fqdn.key" "$CERT_DIR/server.key"

echo "tailscale-certs: $CERT_DIR/server.crt -> $fqdn.crt"
echo "tailscale-certs: $CERT_DIR/server.key -> $fqdn.key"
