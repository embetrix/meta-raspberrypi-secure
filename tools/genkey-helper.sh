#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Generate all signing keys for meta-raspberrypi-secure and print the
# corresponding BitBake variables to set in local.conf or kas header
#
# Usage: genkey-helper.sh [KEY_DIR] [KAS_FRAGMENT]
#   KEY_DIR       directory to store generated keys (default: rpi-secure-keys)
#   KAS_FRAGMENT  path to kas fragment to generate (default: kas-signing-keys.yml)

set -e
umask 077
KEY_DIR="${1:-rpi-secure-keys}"
KEY_DIR="$(cd "$(dirname "$KEY_DIR")" 2>/dev/null && pwd)/$(basename "$KEY_DIR")" || KEY_DIR="$(readlink -f "$KEY_DIR")"

CN="rpi-secure"
ORG="Embetrix"
DAYS=3650

mkdir -p "$KEY_DIR"

echo "Generating signing keys in: $KEY_DIR:"

# Secure-boot signing private key (RSA 2048) 
SECBOOT_KEY="$KEY_DIR/privkey_secure-bootsign.pem"
if [ -f "$SECBOOT_KEY" ]; then
    echo "  Skipping secure-boot signing key (already exists)"
else
    echo "  Generating secure-boot signing key (RSA-2048) ..."
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
        -out "$SECBOOT_KEY" 2>/dev/null
    chmod 600 "$SECBOOT_KEY"
fi

# AVB signing private key (RSA 4096)
AVB_SIGN_KEY="$KEY_DIR/privkey_avb.pem"
if [ -f "$AVB_SIGN_KEY" ]; then
    echo "  Skipping AVB signing key (already exists)"
else
    echo "  Generating AVB signing key (RSA-4096) ..."
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
        -out "$AVB_SIGN_KEY" 2>/dev/null
    chmod 600 "$AVB_SIGN_KEY"
fi

# AVB self-signed x509 certificate (PEM)
AVB_X509="$KEY_DIR/x509_avb.pem"
if [ -f "$AVB_X509" ]; then
    echo "  Skipping AVB x509 certificate (already exists)"
else
    echo "  Generating AVB x509 certificate (PEM) ..."
    openssl req -new -x509 -sha256 -days "$DAYS" -batch \
        -subj "/CN=$CN-avb dev/O=$ORG" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "subjectKeyIdentifier=hash" \
        -key "$AVB_SIGN_KEY" -outform PEM -out "$AVB_X509" 2>/dev/null
    chmod 644 "$AVB_X509"
fi

# IMA/EVM private key (EC prime256v1)
IMA_PRIVKEY="$KEY_DIR/privkey_ima.pem"
if [ -f "$IMA_PRIVKEY" ]; then
    echo "  Skipping IMA/EVM private key (already exists)"
else
    echo "  Generating IMA/EVM private key ..."
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -out "$IMA_PRIVKEY" 2>/dev/null
    chmod 600 "$IMA_PRIVKEY"
fi

# IMA/EVM x509 certificate (DER)
IMA_X509="$KEY_DIR/x509_ima.der"
if [ -f "$IMA_X509" ]; then
    echo "  Skipping IMA/EVM x509 certificate (already exists)"
else
    echo "  Generating IMA/EVM x509 certificate (DER) ..."
    openssl req -new -x509 -sha256 -days "$DAYS" -batch \
        -subj "/CN=$CN-imaevm dev/O=$ORG" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "subjectKeyIdentifier=hash" \
        -key "$IMA_PRIVKEY" -outform DER -out "$IMA_X509" 2>/dev/null
    chmod 644 "$IMA_X509"
fi

# Kernel module signing private key (EC prime256v1) 
MODSIGN_PRIVKEY="$KEY_DIR/privkey_modsign.pem"
if [ -f "$MODSIGN_PRIVKEY" ]; then
    echo "  Skipping kernel module signing private key (already exists)"
else
    echo "  Generating kernel module signing private key ..."
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -out "$MODSIGN_PRIVKEY" 2>/dev/null
    chmod 600 "$MODSIGN_PRIVKEY"
fi

# Kernel module signing x509 certificate (PEM)
MODSIGN_X509="$KEY_DIR/x509_modsign.pem"
if [ -f "$MODSIGN_X509" ]; then
    echo "  Skipping kernel module signing x509 certificate (already exists)"
else
    echo "  Generating kernel module signing x509 certificate (PEM) ..."
    openssl req -new -x509 -sha256 -days "$DAYS" -batch \
        -subj "/CN=$CN-modsign dev/O=$ORG" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "subjectKeyIdentifier=hash" \
        -key "$MODSIGN_PRIVKEY" -outform PEM -out "$MODSIGN_X509" 2>/dev/null
    chmod 644 "$MODSIGN_X509"
fi

# SWUpdate CMS signing private key (EC prime256v1)
SWUPDATE_CMS_KEY="$KEY_DIR/privkey_swupdate.pem"
if [ -f "$SWUPDATE_CMS_KEY" ]; then
    echo "  Skipping SWUpdate CMS signing key (already exists)"
else
    echo "  Generating SWUpdate CMS signing key (EC prime256v1) ..."
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -out "$SWUPDATE_CMS_KEY" 2>/dev/null
    chmod 600 "$SWUPDATE_CMS_KEY"
fi

# SWUpdate CMS signing x509 certificate (PEM)
SWUPDATE_CMS_CERT="$KEY_DIR/x509_swupdate.pem"
if [ -f "$SWUPDATE_CMS_CERT" ]; then
    echo "  Skipping SWUpdate CMS x509 certificate (already exists)"
else
    echo "  Generating SWUpdate CMS x509 certificate (PEM) ..."
    openssl req -new -x509 -sha256 -days "$DAYS" -batch \
        -subj "/CN=$CN-swupdate dev/O=$ORG" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "subjectKeyIdentifier=hash" \
        -key "$SWUPDATE_CMS_KEY" -outform PEM -out "$SWUPDATE_CMS_CERT" 2>/dev/null
    chmod 644 "$SWUPDATE_CMS_CERT"
fi

# SWUpdate AES encryption key file (AES-256-CBC key + iv)
SWUPDATE_AES_FILE="$KEY_DIR/swupdate-aes.key"
if [ -f "$SWUPDATE_AES_FILE" ]; then
    echo "  Skipping SWUpdate AES key file (already exists)"
else
    echo "  Generating SWUpdate AES key file (AES-256-CBC) ..."
    openssl enc -aes-256-cbc -k "$(openssl rand -hex 32)" -P -md sha1 -nosalt 2>/dev/null \
        | tr -d ' ' > "$SWUPDATE_AES_FILE"
    chmod 600 "$SWUPDATE_AES_FILE"
fi

# SSH CA key pair (ed25519)
SSH_CA_KEY="$KEY_DIR/ssh_ca_key"
SSH_CA_PUB="$KEY_DIR/ssh_ca_key.pub"
SSH_CLIENT_KEY="$KEY_DIR/ssh_client"
SSH_CLIENT_PUB="$KEY_DIR/ssh_client.pub"
SSH_ROOT_KEY="$KEY_DIR/ssh_root"
SSH_ROOT_PUB="$KEY_DIR/ssh_root.pub"
KAS_FRAGMENT="${2:-$PWD/kas-signing-keys.yml}"
# ssh-keygen requires a valid passwd entry:
# create a temporary one in CI for the current uid if missing
getent passwd "$(id -u)" >/dev/null 2>&1 || echo "build:x:$(id -u):$(id -g)::/tmp:/sbin/nologin" >> /etc/passwd
if [ -f "$SSH_CA_KEY" ]; then
    echo "  Skipping SSH CA key pair (already exists)"
else
    echo "  Generating SSH CA key pair (ed25519) ..."
    HOME=/tmp ssh-keygen -t ed25519 -f "$SSH_CA_KEY" -N "" -C "$ORG SSH CA" -q
    chmod 600 "$SSH_CA_KEY"
    chmod 644 "$SSH_CA_PUB"
fi

if [ -f "$SSH_CLIENT_KEY" ]; then
    echo "  Skipping SSH client key pair (already exists)"
else
    echo "  Generating SSH client key pair (ed25519) ..."
    HOME=/tmp ssh-keygen -t ed25519 -f "$SSH_CLIENT_KEY" -N "" -C "$ORG SSH client" -q
    chmod 600 "$SSH_CLIENT_KEY"
    chmod 644 "$SSH_CLIENT_PUB"
fi

if [ -f "$SSH_ROOT_KEY" ]; then
    echo "  Skipping SSH root key pair (already exists)"
else
    echo "  Generating SSH root key pair (ed25519) ..."
    HOME=/tmp ssh-keygen -t ed25519 -f "$SSH_ROOT_KEY" -N "" -C "$ORG SSH root" -q
    chmod 600 "$SSH_ROOT_KEY"
    chmod 644 "$SSH_ROOT_PUB"
fi

# Auto-generate a ready-to-use kas fragment with resolved key paths.
cat > "$KAS_FRAGMENT" <<EOF
# Generated by $(basename "$0") on $(date)
header:
    version: 14

local_conf_header:
    signing_keys: |
        RPI_SIGNING_KEYS_DIR     = "$KEY_DIR"
        RPI_SECURE_BOOT_SIGN_KEY = "$SECBOOT_KEY"
        AVB_SIGN_KEY             = "$AVB_SIGN_KEY"
        AVB_X509                 = "$AVB_X509"
        IMA_EVM_PRIVKEY          = "$IMA_PRIVKEY"
        IMA_EVM_X509             = "$IMA_X509"
        MODSIGN_PRIVKEY          = "$MODSIGN_PRIVKEY"
        MODSIGN_X509             = "$MODSIGN_X509"
        SWUPDATE_CMS_KEY         = "$SWUPDATE_CMS_KEY"
        SWUPDATE_CMS_CERT        = "$SWUPDATE_CMS_CERT"
        SWUPDATE_AES_FILE        = "$SWUPDATE_AES_FILE"
        OPENSSH_CA_PUBKEY        = "$SSH_CA_PUB"
EOF
chmod 600 "$KAS_FRAGMENT"


echo
echo "All keys generated successfully."
echo
echo "Add the following to your local.conf (or kas header):"
echo "#######################################################"
cat <<EOF
RPI_SIGNING_KEYS_DIR     = "$KEY_DIR"
RPI_SECURE_BOOT_SIGN_KEY = "$SECBOOT_KEY"
AVB_SIGN_KEY             = "$AVB_SIGN_KEY"
AVB_X509                 = "$AVB_X509"
IMA_EVM_PRIVKEY          = "$IMA_PRIVKEY"
IMA_EVM_X509             = "$IMA_X509"
MODSIGN_PRIVKEY          = "$MODSIGN_PRIVKEY"
MODSIGN_X509             = "$MODSIGN_X509"
SWUPDATE_CMS_KEY         = "$SWUPDATE_CMS_KEY"
SWUPDATE_CMS_CERT        = "$SWUPDATE_CMS_CERT"
SWUPDATE_AES_FILE        = "$SWUPDATE_AES_FILE"
OPENSSH_CA_PUBKEY        = "$SSH_CA_PUB"
EOF
echo "#######################################################"
echo
echo "Generated kas fragment: $KAS_FRAGMENT"
echo "Use it directly in your build:"
echo "  kas build kas-rpi-secure.yml:$KAS_FRAGMENT"
echo
echo "SSH CA private key (keep secret): $SSH_CA_KEY"
echo
echo "To sign the client keys with the CA:"
echo "  ssh-keygen -s $SSH_CA_KEY -I user-rpi  -n rpi  -V +1w $SSH_CLIENT_PUB"
echo "  ssh-keygen -s $SSH_CA_KEY -I user-root -n root -V +1d $SSH_ROOT_PUB"
echo
echo "To connect:"
echo "  ssh -i $SSH_CLIENT_KEY rpi@<device-ip>"
echo "  ssh -i $SSH_ROOT_KEY root@<device-ip>"
echo
echo "NOTICE: These file-based keys are not suitable for high security requirements :"
echo "For production, store private keys in a Hardware Security Module (HSM)"
echo "or TPM and use PKCS#11 URIs instead of file based keys"
echo