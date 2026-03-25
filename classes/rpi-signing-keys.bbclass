# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Signing key validation/generation:
#   dev  : auto-generate temporary keys
#   prod : error if any key missing or still using dev defaults

RPI_SIGNING_KEYS_DIR     ?= "${TMPDIR}/dev-signing-keys"
MODSIGN_PRIVKEY          ?= "${RPI_SIGNING_KEYS_DIR}/privkey_modsign.pem"
MODSIGN_X509             ?= "${RPI_SIGNING_KEYS_DIR}/x509_modsign.pem"
IMA_EVM_PRIVKEY          ?= "${RPI_SIGNING_KEYS_DIR}/privkey_ima.pem"
IMA_EVM_X509             ?= "${RPI_SIGNING_KEYS_DIR}/x509_ima.der"
RPI_SECURE_BOOT_SIGN_KEY ?= "${RPI_SIGNING_KEYS_DIR}/privkey_secure-bootsign.pem"

addhandler rpi_check_signing_keys
rpi_check_signing_keys[eventmask] = "bb.event.BuildStarted"

python rpi_check_signing_keys() {

    import os

    d = e.data
    profile = d.getVar('RPI_SECURITY_PROFILE') or 'dev'
    # Only this path is considered ephemeral dev keys in production checks.
    tmpdir = d.getVar('TMPDIR') or ''
    dev_dir = os.path.normpath(os.path.join(tmpdir, 'dev-signing-keys')) if tmpdir else ''

    key_defs = [
        ('IMA_EVM_PRIVKEY',  'ec'),
        ('IMA_EVM_X509',     'der'),
        ('MODSIGN_PRIVKEY',  'ec'),
        ('MODSIGN_X509',     'pem'),
    ]
    if d.getVar('RPI_SECURE_BOOT_SIGN') == '1':
        key_defs.append(('RPI_SECURE_BOOT_SIGN_KEY', 'rsa'))

    keys = [(n, d.getVar(n), t) for n, t in key_defs]

    if profile == 'prod':
        errors = []
        for name, path, _ in keys:
            if not path or not os.path.isfile(path):
                errors.append("  %s (not set)" % name)
            elif dev_dir and (os.path.normpath(path) == dev_dir or os.path.normpath(path).startswith(dev_dir + os.sep)):
                errors.append("  %s = %s" % (name, path))
        if errors:
            bb.fatal("Production build requires signing keys to be explicitly configured " \
                     "and not using dev-signing-keys:\n" + "\n".join(errors) + "\n\n" \
                     "Use scripts/genkey-helper.sh <KEY_DIR> to generate keys and " \
                     "kas-signing-keys.generated.yml in the layer root, then build with: " \
                     "kas build kas-rpi-secure.yml:kas-signing-keys.generated.yml")
        return

    missing = [(n, p, t) for n, p, t in keys if not p or not os.path.isfile(p)]
    if not missing:
        return

    bb.warn("Dev build: generating temporary signing keys.")
    for name, path, ktype in missing:
        if not path:
            bb.fatal("%s is not set" % name)
        bb.utils.mkdirhier(os.path.dirname(path))
        if ktype in ('ec', 'rsa'):
            _gen_privkey(path, ktype)
        else:
            _gen_cert(name, path, keys, ktype)
        bb.warn("  Generated %s" % path)
}

def _gen_privkey(path, ktype):
    import subprocess, os
    opts = {'ec': ('EC', 'ec_paramgen_curve:prime256v1'),
            'rsa': ('RSA', 'rsa_keygen_bits:2048')}
    algo, param = opts[ktype]
    subprocess.check_call(['openssl', 'genpkey', '-algorithm', algo, '-pkeyopt', param, '-out', path])
    os.chmod(path, 0o600)

def _gen_cert(cert_name, cert_path, keys, fmt):
    import subprocess, tempfile, os
    prefix = cert_name.rsplit('_', 1)[0]
    privkey = next((p for n, p, _ in keys if n.startswith(prefix) and n.endswith('PRIVKEY') and p and os.path.isfile(p)), None)
    if not privkey:
        bb.fatal("Cannot generate %s: no matching private key" % cert_name)
    outform = fmt.upper()
    cnf = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.cnf', delete=False) as f:
            f.write("[req]\n"
                    "distinguished_name=dn\n"
                    "x509_extensions=v3\n"
                    "prompt=no\n"
                    "[dn]\n"
                    "CN=rpi-secure dev\n"
                    "O=Embetrix\n"
                    "[v3]\n"
                    "basicConstraints=critical,CA:FALSE\n"
                    "keyUsage=digitalSignature\n"
                    "extendedKeyUsage=critical,codeSigning\n"
                    "subjectKeyIdentifier=hash\n")
            cnf = f.name
        subprocess.check_call(['openssl', 'req', '-new', '-x509', '-sha256', '-days', '3650',
                                '-batch', '-config', cnf, '-key', privkey, '-outform', outform, '-out', cert_path])
    finally:
        if cnf:
            os.unlink(cnf)
    os.chmod(cert_path, 0o644)
