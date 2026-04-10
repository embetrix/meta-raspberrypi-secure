# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Stage a bundled PEM (IMA/EVM x509 + module signing x509) into the kernel
# build dir / shared-workdir so that CONFIG_SYSTEM_TRUSTED_KEYS="ima_evm_key.pem"
# embeds both certs into the builtin trusted keyring at kernel build time
#
# Rationale: when only the IMA cert was placed in CONFIG_SYSTEM_TRUSTED_KEYS,
# kernel module signature verification broke in practice, so we bundle the
# modsign cert into the same PEM to guarantee it ends up in .builtin_trusted_keys
#
# Note: unlike CONFIG_MODULE_SIG_KEY (which expects a PEM bundle containing the
# private key), CONFIG_SYSTEM_TRUSTED_KEYS only needs certificates
#
# If a root CA model is ever adopted (IMA_EVM_ROOT_CA), bundle the CA here
# instead of the leaf so only the CA is baked into .builtin_trusted_keys and
# leaf certs can be rotated without rebuilding the kernel

DEPENDS:append = " openssl-native"

kernel_do_configure:prepend() {

    if [ ! -f "${IMA_EVM_X509}" ]; then
        bberror "IMA/EVM certificate not found: ${IMA_EVM_X509}"
        exit 1
    fi
    if [ ! -f "${MODSIGN_X509}" ]; then
        bberror "Module signing certificate not found: ${MODSIGN_X509}"
        exit 1
    fi

    # IMA/EVM cert is DER so convert to PEM so the bundle is a uniform
    openssl x509 -inform DER -in "${IMA_EVM_X509}" \
                 -outform PEM -out "${B}/trusted_keys.pem"
    # Modsign cert is already PEM so append it directly to the bundle
    cat "${MODSIGN_X509}" >> "${B}/trusted_keys.pem"
}

do_shared_workdir:append() {

    cp trusted_keys.pem $kerneldir/
}
