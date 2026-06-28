# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Signing key validation:
#   Keys must always be explicitly provided via genkey-helper.sh and
#   a kas signing-keys fragment. Auto-generation is intentionally not
#   supported ephemeral keys risk permanently bricking secure boot
#   if the EEPROM is flashed and the keys are later lost

RPI_SIGNING_KEYS_DIR     ?= ""
RPI_SECURE_BOOT_SIGN_KEY ?= "${RPI_SIGNING_KEYS_DIR}/privkey_secure-bootsign.pem"
AVB_SIGN_KEY             ?= "${RPI_SIGNING_KEYS_DIR}/privkey_avb.pem"
AVB_X509                 ?= "${RPI_SIGNING_KEYS_DIR}/x509_avb.pem"
IMA_EVM_PRIVKEY          ?= "${RPI_SIGNING_KEYS_DIR}/privkey_ima.pem"
IMA_EVM_X509             ?= "${RPI_SIGNING_KEYS_DIR}/x509_ima.der"
MODSIGN_PRIVKEY          ?= "${RPI_SIGNING_KEYS_DIR}/privkey_modsign.pem"
MODSIGN_X509             ?= "${RPI_SIGNING_KEYS_DIR}/x509_modsign.pem"
SWUPDATE_CMS_KEY         ?= "${RPI_SIGNING_KEYS_DIR}/privkey_swupdate.pem"
SWUPDATE_CMS_CERT        ?= "${RPI_SIGNING_KEYS_DIR}/x509_swupdate.pem"
SWUPDATE_AES_FILE        ?= "${RPI_SIGNING_KEYS_DIR}/swupdate-aes.key"
OPENSSH_CA_PUBKEY        ?= "${RPI_SIGNING_KEYS_DIR}/ssh_ca_key.pub"

addhandler rpi_check_signing_keys
rpi_check_signing_keys[eventmask] = "bb.event.BuildStarted"

python rpi_check_signing_keys() {

    import os

    d = e.data

    key_defs = [
        ('RPI_SECURE_BOOT_SIGN_KEY', 'private key'),
        ('AVB_SIGN_KEY',             'private key'),
        ('AVB_X509',                 'certificate'),
        ('IMA_EVM_PRIVKEY',          'private key'),
        ('IMA_EVM_X509',             'certificate'),
        ('MODSIGN_PRIVKEY',          'private key'),
        ('MODSIGN_X509',             'certificate'),
        ('SWUPDATE_CMS_KEY',         'private key'),
        ('SWUPDATE_CMS_CERT',        'certificate'),
        ('SWUPDATE_AES_FILE',        'AES key'),
        ('OPENSSH_CA_PUBKEY',        'SSH CA public key'),
    ]

    # These may hold a space-separated list of files (e.g. a classical
    # plus a pqc so every entry must exist)
    list_vars = ('SWUPDATE_CMS_KEY', 'SWUPDATE_CMS_CERT')

    errors = []
    for name, desc in key_defs:
        value = d.getVar(name)
        paths = value.split() if (value and name in list_vars) else [value]
        if not value:
            errors.append("  %s (%s not found)" % (name, desc))
            continue
        for path in paths:
            if not os.path.isfile(path):
                errors.append("  %s (%s not found: %s)" % (name, desc, path))

    if errors:
        bb.fatal("Signing keys are missing:\n" + "\n".join(errors) + "\n\n" \
                 "Generate keys with:\n" \
                 "  tools/genkey-helper.sh <KEY_DIR>\n\n" \
                 "Then build with:\n" \
                 "  kas build kas-rpi-secure.yml:kas-signing-keys.yml")
}
