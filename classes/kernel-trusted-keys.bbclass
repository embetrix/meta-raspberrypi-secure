
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# BitBake class: kernel-trusted-keys.bbclass
#
# Purpose:
#   Bundle multiple X.509 certificates (IMA/EVM, module signing, AVB, etc.) into a single PEM file (trusted_keys.pem)
#   for use with CONFIG_SYSTEM_TRUSTED_KEYS in the Linux kernel build. This ensures all required certificates are
#   embedded in the kernel's builtin trusted keyring at build time.
#
# Usage:
#   - Set KERNEL_TRUSTED_KEYS to a space-separated list of certificate files (PEM or DER).
#     Example:
#       KERNEL_TRUSTED_KEYS = "${IMA_EVM_X509} ${MODSIGN_X509} ${AVB_X509}"
#   - Inherit this class in your kernel recipe or .bbappend.
#   - Set CONFIG_SYSTEM_TRUSTED_KEYS="trusted_keys.pem" in your kernel config.
#
# Notes:
#   - All certificates are converted to PEM if needed and concatenated.
#   - Only public certificates are required (no private keys).
#   - If a root CA model is adopted, bundle the CA cert here for easier leaf rotation.
#   - If any certificate is missing or invalid, the build will fail


KERNEL_TRUSTED_KEYS ?= "${IMA_EVM_X509} ${MODSIGN_X509} ${AVB_X509}"

DEPENDS:append = " openssl-native"

kernel_do_configure:prepend() {

    out="${B}/trusted_keys.pem"
    rm -f "$out"
    touch "$out"

    for cert in ${KERNEL_TRUSTED_KEYS}; do
        if [ ! -f "$cert" ]; then
            bbfatal "Trusted key certificate not found: ${cert}"
        fi
        # Detect format and always append as PEM
        if openssl x509 -in "$cert" -inform PEM -noout >/dev/null 2>&1; then
            cat "$cert" >> "$out"
        elif openssl x509 -in "$cert" -inform DER -noout >/dev/null 2>&1; then
            openssl x509 -in "$cert" -inform DER -outform PEM >> "$out" \
                || bbfatal "Failed to convert DER certificate to PEM: ${cert}"
        else
            bbfatal "Unsupported or invalid certificate format: ${cert}"
        fi
    done
}

do_shared_workdir:append() {

    cp trusted_keys.pem $kerneldir/
}
