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


addhandler rpi_check_signing_keys
rpi_check_signing_keys[eventmask] = "bb.event.BuildStarted"

python rpi_check_signing_keys() {

    import os

    d = e.data

    key_defs = [
        ('RPI_SECURE_BOOT_SIGN_KEY', 'private key'),
        ('AVB_SIGN_KEY',     'private key'),
        ('AVB_X509',         'certificate'),
        ('IMA_EVM_PRIVKEY',  'private key'),
        ('IMA_EVM_X509',     'certificate'),
        ('MODSIGN_PRIVKEY',  'private key'),
        ('MODSIGN_X509',     'certificate'),
    ]

    errors = []
    for name, desc in key_defs:
        path = d.getVar(name)
        if not path or not os.path.isfile(path):
            errors.append("  %s (%s not found)" % (name, desc))

    if errors:
        bb.fatal("Signing keys are missing:\n" + "\n".join(errors) + "\n\n" \
                 "Generate keys with:\n" \
                 "  scripts/genkey-helper.sh <KEY_DIR>\n\n" \
                 "Then build with:\n" \
                 "  kas build kas-rpi-secure.yml:kas-signing-keys.yml")
}
